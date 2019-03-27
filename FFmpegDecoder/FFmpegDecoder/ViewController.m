//
//  ViewController.m
//  FFmpegDecoder
//
//  Created by luowailin on 2019/3/27.
//  Copyright © 2019 luowailin. All rights reserved.
//

#import "ViewController.h"
#import <libavcodec/avcodec.h>
#import <libavformat/avformat.h>
#import <libavutil/imgutils.h>
#import <libswscale/swscale.h>

@interface ViewController ()

@property (weak, nonatomic) IBOutlet UITextField *inputFile;
@property (weak, nonatomic) IBOutlet UITextField *outfile;
@property (weak, nonatomic) IBOutlet UILabel *infoText;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
}

- (IBAction)decodecAction:(id)sender {
    
    AVFormatContext *pFormatCtx;
    
    int i, videoIndex;
    AVCodecContext *pCodecCtx;
    AVCodec *pCodec;
    AVFrame *pFrame, *pFrameYUV;
    
    uint8_t *out_buffer;
    AVPacket *packet;
    
    int y_size;
    int ret, got_picture;
    struct SwsContext *img_convert_ctx;
    FILE *fp_yuv;
    
    int frame_cnt;
    clock_t time_start, time_finish;
    double time_duration = 0.0;
    
    char input_str_full[500] = {0};
    char output_str_full[500] = {0};
    char info[1000] = {0};
    
    NSString *input_str = self.inputFile.text;
    NSString *output_str = self.outfile.text;
    
    NSString *input_nsstr =  [[[NSBundle mainBundle] resourcePath]
                              stringByAppendingPathComponent:self.inputFile.text];
    NSString *output_nsstr = [[[NSBundle mainBundle] resourcePath]
                            stringByAppendingPathComponent:self.outfile.text];
    
    sprintf(input_str_full, "%s", [input_nsstr UTF8String]);
    sprintf(output_str_full, "%s", [output_nsstr UTF8String]);
    
    printf("Input Path: %s\n", input_str_full);
    printf("Output Path:%s\n", output_str_full);
    
    avformat_network_init();
    pFormatCtx = avformat_alloc_context();
    if (avformat_open_input(&pFormatCtx, input_str_full, NULL, NULL)) {
        printf("Couldn't open input stream.\n");
        return;
    }
    
    if (avformat_find_stream_info(pFormatCtx, NULL) < 0) {
        printf("Couldn't find stream information.\n");
        return;
    }
    
    videoIndex = -1;
    for (i = 0; i < pFormatCtx->nb_streams; i ++) {
        if (pFormatCtx->streams[i]->codecpar->codec_type == AVMEDIA_TYPE_VIDEO) {
            videoIndex = i;
            break;
        }
    }
    
    if (videoIndex == -1) {
        printf("Couldn't find a video stream.\n");
        return;
    }
    
    AVStream *in_stream = pFormatCtx->streams[videoIndex];
    pCodec = avcodec_find_decoder(in_stream->codecpar->codec_id);
    
    pCodecCtx = avcodec_alloc_context3(pCodec);
    ret = avcodec_parameters_to_context(pCodecCtx, in_stream->codecpar); //把parameters放到AVCodecContext中
    if (ret < 0) {
        printf("Failed to copy context input to output stream codec context");
        return;
    }
/*
    pCodecCtx = pFormatCtx->streams[videoIndex]->codec;
    pCodec = avcodec_find_decoder(pCodecCtx->codec_id);
    */
    
    if (pCodec == NULL) {
        printf("Couldn't find Codec.\n");
        return;
    }
    
    if (avcodec_open2(pCodecCtx, pCodec, NULL) < 0) {
        printf("Couldn't open codec.\n");
        return;
    }
    
    
    pFrame = av_frame_alloc();
    pFrameYUV = av_frame_alloc();
    
    out_buffer = (unsigned char *)av_malloc(av_image_get_buffer_size(AV_PIX_FMT_YUV420P,
                                                                     pCodecCtx->width,
                                                                     pCodecCtx->height,
                                                                     1));
    av_image_fill_arrays(pFrameYUV->data,
                         pFrameYUV->linesize,
                         out_buffer,
                         AV_PIX_FMT_YUV420P,
                         pCodecCtx->width,
                         pCodecCtx->height,
                         1);
    
    packet = (AVPacket *)av_malloc(sizeof(AVPacket));
    
    img_convert_ctx = sws_getContext(pCodecCtx->width,
                                     pCodecCtx->height,
                                     pCodecCtx->pix_fmt,
                                     pCodecCtx->width,
                                     pCodecCtx->height,
                                     AV_PIX_FMT_YUV420P,
                                     SWS_BICUBIC,
                                     NULL, NULL, NULL);
    
    sprintf(info, "[Input ] %s\n", [input_str UTF8String]);
    sprintf(info, "%s[Output ] %s\n", info, [output_str UTF8String]);
    sprintf(info, "%s[Format ] %s\n", info, pFormatCtx->iformat->name);
    sprintf(info, "%s[Codec ] %s\n", info, pCodecCtx->codec->name);
    sprintf(info, "%s[Resolution]%dx%d\n", info, pCodecCtx->width, pCodecCtx->height);
    
    fp_yuv = fopen(output_str_full, "wb+");
    if (fp_yuv == NULL) {
        printf("Cannot open output file.\n");
        return;
    }
    
    frame_cnt = 0;
    time_start = clock();
    
    while (av_read_frame(pFormatCtx, packet) >= 0) {
        if (packet->stream_index == videoIndex) {
            ret = avcodec_decode_video2(pCodecCtx,
                                        pFrame,
                                        &got_picture,
                                        packet);
            if (ret < 0) {
                printf("Decode Error.\n");
                return;
            }
            
            if (got_picture) {
                sws_scale(img_convert_ctx,
                          (const uint8_t * const *)pFrame->data,
                          pFrame->linesize,
                          0,
                          pCodecCtx->height,
                          pFrameYUV->data,
                          pFrameYUV->linesize);
                
                y_size = pCodecCtx->width * pCodecCtx->height;
                fwrite(pFrameYUV->data[0], 1, y_size, fp_yuv);
                fwrite(pFrameYUV->data[1], 1, y_size/4, fp_yuv);
                fwrite(pFrameYUV->data[2], 1, y_size/4, fp_yuv);
                
                char pictype_str[10] = {0};
                switch (pFrame->pict_type) {
                    case AV_PICTURE_TYPE_I:
                        sprintf(pictype_str, "I");
                        break;
                        case AV_PICTURE_TYPE_P:
                        sprintf(pictype_str, "P");
                        break;
                    case AV_PICTURE_TYPE_B:
                        sprintf(pictype_str, "B");
                        break;
                    default:
                        sprintf(pictype_str, "Other");
                        break;
                }
                printf("Frame Index: %5d. Type:%s\n", frame_cnt, pictype_str);
                frame_cnt ++;
            }
        }
        av_packet_unref(packet);
    }
    
    while (1) {
        ret = avcodec_decode_video2(pCodecCtx,
                                    pFrame,
                                    &got_picture,
                                    packet);
        if (ret < 0) {
            break;
        }
        
        if (!got_picture) {
            break;
        }
        
        sws_scale(img_convert_ctx,
                  (const uint8_t * const *)pFrame->data,
                  pFrame->linesize,
                  0,
                  pCodecCtx->height,
                  pFrameYUV->data,
                  pFrameYUV->linesize);
        
        int y_size = pCodecCtx->width * pCodecCtx->height;
        fwrite(pFrameYUV->data[0], 1, y_size, fp_yuv);
        fwrite(pFrameYUV->data[1], 1, y_size/4, fp_yuv);
        fwrite(pFrameYUV->data[2], 1, y_size/4, fp_yuv);
        
        char pictype_str[10] = {0};
        switch (pFrame->pict_type) {
            case AV_PICTURE_TYPE_I:
                sprintf(pictype_str, "I");
                break;
                case AV_PICTURE_TYPE_P:
                sprintf(pictype_str, "P");
                break;
                case AV_PICTURE_TYPE_B:
                sprintf(pictype_str, "B");
                break;
            default:
                sprintf(pictype_str, "Other");
                break;
        }
        printf("Frame Index: %5d. Type:%s\n", frame_cnt, pictype_str);
        frame_cnt ++;
    }
    
    time_finish = clock();
    time_duration = (double)(time_finish - time_start);
    
    sprintf(info, "%s[Time ]%fus\n", info, time_duration);
    sprintf(info, "%s[Count ]%d\n", info, frame_cnt);
    
    sws_freeContext(img_convert_ctx);
    
    fclose(fp_yuv);
    
    av_frame_free(&pFrameYUV);
    av_frame_free(&pFrame);
    avcodec_close(pCodecCtx);
    avformat_close_input(&pFormatCtx);
    
    NSString *info_ns = [NSString stringWithFormat:@"%s", info];
    self.infoText.text = info_ns;
}

@end

