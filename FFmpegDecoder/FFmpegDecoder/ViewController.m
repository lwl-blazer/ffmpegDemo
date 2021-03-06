//
//  ViewController.m
//  FFmpegDecoder
//
//  Created by luowailin on 2019/3/27.
//  Copyright © 2019 luowailin. All rights reserved.
//
// https://blog.csdn.net/x_iya/article/details/52299058

#import "ViewController.h"
#import <libavcodec/avcodec.h>
#import <libavformat/avformat.h>
#import <libavutil/imgutils.h>
#import <libswscale/swscale.h>

@interface ViewController (){
    AVPicture picture;
}

@property (weak, nonatomic) IBOutlet UITextField *inputFile;
@property (weak, nonatomic) IBOutlet UITextField *outfile;
@property (weak, nonatomic) IBOutlet UILabel *infoText;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
}

- (IBAction)decodecAction:(id)sender {
    
    [self decodeFile];
    return;
    
    AVFormatContext *pFormatCtx; //AVFormatContext 主要是存储音视频格式中包含的信息
    
    int i, videoIndex;
    AVCodecContext *pCodecCtx;
    
    //AVCodec是存储编解码器信息的结构体    每一个编解码器对应一个结构体
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
    if (avformat_open_input(&pFormatCtx, input_str_full, NULL, NULL)) { //打开媒体文件
        printf("Couldn't open input stream.\n");
        return;
    }
    //读取一部分音视频数据并且获得一些相关信息   avformat_find_stream_info()主要用于给每个媒体流(音频/视频)的AVStream赋值
    if (avformat_find_stream_info(pFormatCtx, NULL) < 0) {
        printf("Couldn't find stream information.\n");
        return;
    }
    
    //获取视频流下标
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
    ret = avcodec_parameters_to_context(pCodecCtx, in_stream->codecpar); //把parameters放到AVCodecContext中 在解码器中主要的作用是配置
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
    
    if (avcodec_open2(pCodecCtx, pCodec, NULL) < 0) { //avcodec_open2  该函数用于初始化一个音视频编码器的AVCodecContext，如果在编码器中检查输入的参数是否符合编码器要求，(注：解码器的参数大部分都是由系统自动设定而不是由用户设定)
        printf("Couldn't open codec.\n");
        return;
    }
    
    pFrame = av_frame_alloc();
    pFrameYUV = av_frame_alloc();
    
    //分配内存空间，用来保存原始数据     av_image_get_buffer_size获取AV_PIX_FMT_YUV420P需要的存储空间
    out_buffer = (unsigned char *)av_malloc(av_image_get_buffer_size(AV_PIX_FMT_YUV420P,
                                                                     pCodecCtx->width,
                                                                     pCodecCtx->height,
                                                                     1));
    
    //关联frame 和 刚分配的内存(out_buffer)
    av_image_fill_arrays(pFrameYUV->data,
                         pFrameYUV->linesize,
                         out_buffer,
                         AV_PIX_FMT_YUV420P,
                         pCodecCtx->width,
                         pCodecCtx->height,
                         1);
    
    packet = (AVPacket *)av_malloc(sizeof(AVPacket));
    
    /** libswscale 是一个主要用于处理图片像素数据的类库。可以完成图片像素格式的转换，图片的拉伸等工作
     *
     * SwsContext是使用libswscale时候一个贯穿始终的结构体。
     *
     * sws_getContext()是初始化SwsContext的函数
     参数:
     srcW: 源图像的宽
     srcH: 源图像的高
     srcFormat: 源图像的像素格式
     dstW: 目标图像的宽
     dstH: 目标图像的高
     dstFormat: 目标图像的像素格式
     flags: 设定图像拉伸使用的算法
     */
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
                                        packet);   //avcodec_decode_video2 解码一帧的视频数据
            if (ret < 0) {
                printf("Decode Error.\n");
                return;
            }
            
            if (got_picture) {
                //sws_scale 用于转换像素的函数
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

- (void)decodeViewFile{
    char input_str_full[500] = {0};
    char output_str_full[500] = {0};
    char output_str_full_h264[500] = {0};
    NSString *input_nsstr =  [[[NSBundle mainBundle] resourcePath]
                              stringByAppendingPathComponent:@"testVideo-1.mp4"];
    NSString *output_nsstr = [[[NSBundle mainBundle] resourcePath]
                              stringByAppendingPathComponent:@"film.yuv"];
    NSString *output_nsstr_h264 = [[[NSBundle mainBundle] resourcePath]
                                   stringByAppendingPathComponent:@"film.h264"];
    sprintf(input_str_full, "%s", [input_nsstr UTF8String]);
    sprintf(output_str_full, "%s", [output_nsstr UTF8String]);
    sprintf(output_str_full_h264, "%s", [output_nsstr_h264 UTF8String]);
    
    printf("Input Path: %s\n", input_str_full);
    printf("Output Path:%s\n", output_str_full);
    
    FILE *fp_yuv = fopen(output_str_full, "wb+");
    FILE *fp_h264 = fopen(output_str_full_h264, "wb+");
    if (fp_yuv == NULL || fp_h264 == NULL) {
        NSLog(@"FILE open Error");
        return;
    }
    
    
    AVFormatContext *pFormatCtx = NULL;
    AVCodecContext *pCodecCtx = NULL;
    
    AVCodec *pCodec = NULL;
    AVFrame *pFrame = NULL, *pFrameYUV = NULL;
    unsigned char *out_buffer = NULL;
    
    AVPacket packet;
    struct SwsContext *img_convert_ctx = NULL;
    
    int got_picture;
    int videoIndex;
    int frame_cnt = 1;
    
    avformat_network_init();
    
    if (avformat_open_input(&pFormatCtx, input_str_full, NULL, NULL) != 0) {
        NSLog(@"Couldn't open an input stream");
        return;
    }
    
    if (avformat_find_stream_info(pFormatCtx, NULL) < 0) {
        NSLog(@"Couldn't find stream information");
        return;
    }
    
    videoIndex = -1;
    for (int i = 0; i < pFormatCtx->nb_streams; i ++) {
        if (pFormatCtx->streams[i]->codec->codec_type == AVMEDIA_TYPE_VIDEO) {
            videoIndex = i;
            break;
        }
    }
    
    if (videoIndex == -1) {
        NSLog(@"Couldn't find stream information");
        return;
    }
    
    pCodecCtx = pFormatCtx->streams[videoIndex]->codec;
    pCodec = avcodec_find_decoder(pCodecCtx->codec_id);
    
    if (pCodec == NULL) {
        NSLog(@"Codec not found");
        return;
    }
    
    if (avcodec_open2(pCodecCtx, pCodec, NULL) < 0) {
        NSLog(@"Could not open codec");
        return;
    }
    
    
    
    pFrame = av_frame_alloc();
    pFrameYUV = av_frame_alloc();
    
    if (pFrame == NULL || pFrameYUV == NULL) {
        NSLog(@"Memory allocation error");
        return;
    }
    
    out_buffer = (unsigned char *)av_malloc(av_image_get_buffer_size(AV_PIX_FMT_YUV420P, pCodecCtx->width, pCodecCtx->height, 1));
    av_image_fill_arrays(pFrameYUV->data, pFrameYUV->linesize, out_buffer, AV_PIX_FMT_YUV420P, pCodecCtx->width, pCodecCtx->height, 1);
    
    img_convert_ctx = sws_getContext(pCodecCtx->width, pCodecCtx->height, pCodecCtx->pix_fmt, pCodecCtx->width, pCodecCtx->height, AV_PIX_FMT_YUV420P, SWS_BICUBIC, NULL, NULL, NULL);
    
    
    unsigned char *dummy = NULL;
    int dummy_len;
    const char nal_start[] = {0, 0, 0, 1};
    AVBitStreamFilterContext *bsfc = av_bitstream_filter_init("h264_mp4toannexb");
    av_bitstream_filter_filter(bsfc, pCodecCtx, NULL, &dummy, &dummy_len, NULL, 0, 0);
    fwrite(pCodecCtx->extradata, pCodecCtx->extradata_size, 1, fp_h264);
    av_bitstream_filter_close(bsfc);
    free(dummy);
    
    while (av_read_frame(pFormatCtx, &packet) >= 0) {
        if (packet.stream_index == videoIndex) {
            fwrite(packet.data, 1, packet.size, fp_h264);
            
            fwrite(nal_start, 4, 1, fp_h264);
            fwrite(packet.data + 4, packet.size - 4, 1, fp_h264);
            if (avcodec_decode_video2(pCodecCtx, pFrame, &got_picture, &packet) < 0) {
                NSLog(@"Decode Error");
                return;
            }
            if (got_picture) {
                sws_scale(img_convert_ctx, (const unsigned char * const *)pFrame->data, pFrame->linesize, 0, pCodecCtx->height, pFrameYUV->data, pFrameYUV->linesize);
                
                
                
                /*
                int y_size = pCodecCtx->width * pCodecCtx->height;
                fwrite(pFrameYUV->data[0], 1, y_size, fp_yuv);
                fwrite(pFrameYUV->data[1], 1, y_size/4, fp_yuv);
                fwrite(pFrameYUV->data[2], 1, y_size/4, fp_yuv);*/
                NSLog(@"Succeed to decode %d frame", frame_cnt);
                frame_cnt ++;
            }
        }
        av_free_packet(&packet);
    }
    
    while (true) {
        if (avcodec_decode_video2(pCodecCtx, pFrame, &got_picture, &packet) < 0) {
            break;
        }
        
        if (!got_picture) {
            break;
        }
        
        sws_scale(img_convert_ctx, (const unsigned char * const *)pFrame->data, pFrame->linesize, 0, pCodecCtx->height, pFrameYUV->data, pFrameYUV->linesize);
        
        int y_size = pCodecCtx->width * pCodecCtx->height;
        fwrite(pFrameYUV->data[0], 1, y_size, fp_yuv);
        fwrite(pFrameYUV->data[1], 1, y_size/4, fp_yuv);
        fwrite(pFrameYUV->data[2], 1, y_size/4, fp_yuv);
        
        NSLog(@"Flush decode : succeed to decode %d frame", frame_cnt);
        frame_cnt ++;
    }
    
    fclose(fp_yuv);
    fclose(fp_h264);
    
    sws_freeContext(img_convert_ctx);
    
    av_free(out_buffer);
    av_frame_free(&pFrame);
    av_frame_free(&pFrameYUV);
    
    avcodec_close(pCodecCtx);
    avformat_close_input(&pFormatCtx);
}

- (UIImage *)imageFromAVFrame:(AVFrame *)frame width:(int)width height:(int)height{
    
    CGBitmapInfo bitmapInfo = kCGBitmapByteOrderDefault;
    CFDataRef data = CFDataCreateWithBytesNoCopy(kCFAllocatorDefault, frame->data[0], frame->linesize[0] * height, kCFAllocatorNull);
    
    CGDataProviderRef provider = CGDataProviderCreateWithCFData(data);
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    
    CGImageRef cgImage = CGImageCreate(width, height, 8, 24, frame->linesize[0], colorSpace, bitmapInfo, provider, NULL, NO, kCGRenderingIntentDefault);
    CGColorSpaceRelease(colorSpace);

    UIImage *image = [UIImage imageWithCGImage:cgImage];
    
    CGImageRelease(cgImage);
    CGDataProviderRelease(provider);
    CFRelease(data);
    return image;
    
}

- (void)decodeFile{
    AVFormatContext    *pFormatCtx;
    int                i, videoindex;
    AVCodecContext    *pCodecCtx;
    AVCodec            *pCodec;
    AVFrame    *pFrame,*pFrameYUV;
    uint8_t *out_buffer;
    AVPacket *packet;
    int y_size;
    int ret, got_picture;
    struct SwsContext *img_convert_ctx;
    FILE *fp_yuv;
    int frame_cnt;
    clock_t time_start, time_finish;
    double  time_duration = 0.0;
    
    char input_str_full[500]={0};
    char output_str_full[500]={0};
    char info[1000]={0};
    
    NSString *input_str=  [[NSBundle mainBundle] pathForResource:self.inputFile.text ofType:@"mp4"];
    NSString *output_str= [NSBundle mainBundle] pathForResource:self.outfile.text ofType:@"" [NSString stringWithFormat:@"resource.bundle/%@",self.outfile.text];
    
    NSString *input_nsstr=[[[NSBundle mainBundle]resourcePath] stringByAppendingPathComponent:input_str];
    NSString *output_nsstr=[[[NSBundle mainBundle]resourcePath] stringByAppendingPathComponent:output_str];
    
    sprintf(input_str_full,"%s",[input_nsstr UTF8String]);
    sprintf(output_str_full,"%s",[output_nsstr UTF8String]);
    
    printf("Input Path:%s\n",input_str_full);
    printf("Output Path:%s\n",output_str_full);
    
    av_register_all();
    avformat_network_init();
    pFormatCtx = avformat_alloc_context();
    
    if(avformat_open_input(&pFormatCtx,input_str_full,NULL,NULL)!=0){
        printf("Couldn't open input stream.\n");
        return ;
    }
    
    if(avformat_find_stream_info(pFormatCtx,NULL)<0){
        printf("Couldn't find stream information.\n");
        return;
    }
    videoindex=-1;
    for(i=0; i<pFormatCtx->nb_streams; i++)
        if(pFormatCtx->streams[i]->codec->codec_type==AVMEDIA_TYPE_VIDEO){
            videoindex=i;
            break;
        }
    if(videoindex==-1){
        printf("Couldn't find a video stream.\n");
        return;
    }
    pCodecCtx=pFormatCtx->streams[videoindex]->codec;
    pCodec=avcodec_find_decoder(pCodecCtx->codec_id);
    if(pCodec==NULL){
        printf("Couldn't find Codec.\n");
        return;
    }
    if(avcodec_open2(pCodecCtx, pCodec,NULL)<0){
        printf("Couldn't open codec.\n");
        return;
    }
    
    pFrame=av_frame_alloc();
    pFrameYUV=av_frame_alloc();
    out_buffer=(unsigned char *)av_malloc(av_image_get_buffer_size(AV_PIX_FMT_YUV420P,  pCodecCtx->width, pCodecCtx->height,1));
    av_image_fill_arrays(pFrameYUV->data, pFrameYUV->linesize,out_buffer,
                         AV_PIX_FMT_YUV420P,pCodecCtx->width, pCodecCtx->height,1);
    packet=(AVPacket *)av_malloc(sizeof(AVPacket));
    
    img_convert_ctx = sws_getContext(pCodecCtx->width, pCodecCtx->height, pCodecCtx->pix_fmt,
                                     pCodecCtx->width, pCodecCtx->height, AV_PIX_FMT_YUV420P, SWS_BICUBIC, NULL, NULL, NULL);
    
    
    sprintf(info,   "[Input     ]%s\n", [input_str UTF8String]);
    sprintf(info, "%s[Output    ]%s\n",info,[output_str UTF8String]);
    sprintf(info, "%s[Format    ]%s\n",info, pFormatCtx->iformat->name);
    sprintf(info, "%s[Codec     ]%s\n",info, pCodecCtx->codec->name);
    sprintf(info, "%s[Resolution]%dx%d\n",info, pCodecCtx->width,pCodecCtx->height);
    
    
    fp_yuv=fopen(output_str_full,"wb+");
    if(fp_yuv==NULL){
        printf("Cannot open output file.\n");
        return;
    }
    
    frame_cnt=0;
    time_start = clock();
    
    while(av_read_frame(pFormatCtx, packet)>=0){
        if(packet->stream_index==videoindex){
            ret = avcodec_decode_video2(pCodecCtx, pFrame, &got_picture, packet);
            if(ret < 0){
                printf("Decode Error.\n");
                return;
            }
            if(got_picture){
                sws_scale(img_convert_ctx, (const uint8_t* const*)pFrame->data, pFrame->linesize, 0, pCodecCtx->height,
                          pFrameYUV->data, pFrameYUV->linesize);
                
                y_size=pCodecCtx->width*pCodecCtx->height;
                fwrite(pFrameYUV->data[0],1,y_size,fp_yuv);    //Y
                fwrite(pFrameYUV->data[1],1,y_size/4,fp_yuv);  //U
                fwrite(pFrameYUV->data[2],1,y_size/4,fp_yuv);  //V
                //Output info
                char pictype_str[10]={0};
                switch(pFrame->pict_type){
                    case AV_PICTURE_TYPE_I:sprintf(pictype_str,"I");break;
                    case AV_PICTURE_TYPE_P:sprintf(pictype_str,"P");break;
                    case AV_PICTURE_TYPE_B:sprintf(pictype_str,"B");break;
                    default:sprintf(pictype_str,"Other");break;
                }
                printf("Frame Index: %5d. Type:%s\n",frame_cnt,pictype_str);
                frame_cnt++;
            }
        }
        av_free_packet(packet);
    }
    //flush decoder
    //FIX: Flush Frames remained in Codec
    while (1) {
        ret = avcodec_decode_video2(pCodecCtx, pFrame, &got_picture, packet);
        if (ret < 0)
            break;
        if (!got_picture)
            break;
        sws_scale(img_convert_ctx, (const uint8_t* const*)pFrame->data, pFrame->linesize, 0, pCodecCtx->height,
                  pFrameYUV->data, pFrameYUV->linesize);
        int y_size=pCodecCtx->width*pCodecCtx->height;
        fwrite(pFrameYUV->data[0],1,y_size,fp_yuv);    //Y
        fwrite(pFrameYUV->data[1],1,y_size/4,fp_yuv);  //U
        fwrite(pFrameYUV->data[2],1,y_size/4,fp_yuv);  //V
        //Output info
        char pictype_str[10]={0};
        switch(pFrame->pict_type){
            case AV_PICTURE_TYPE_I:sprintf(pictype_str,"I");break;
            case AV_PICTURE_TYPE_P:sprintf(pictype_str,"P");break;
            case AV_PICTURE_TYPE_B:sprintf(pictype_str,"B");break;
            default:sprintf(pictype_str,"Other");break;
        }
        printf("Frame Index: %5d. Type:%s\n",frame_cnt,pictype_str);
        frame_cnt++;
    }
    time_finish = clock();
    time_duration=(double)(time_finish - time_start);
    
    sprintf(info, "%s[Time      ]%fus\n",info,time_duration);
    sprintf(info, "%s[Count     ]%d\n",info,frame_cnt);
    
    sws_freeContext(img_convert_ctx);
    
    fclose(fp_yuv);
    
    av_frame_free(&pFrameYUV);
    av_frame_free(&pFrame);
    avcodec_close(pCodecCtx);
    avformat_close_input(&pFormatCtx);
    
    NSString * info_ns = [NSString stringWithFormat:@"%s", info];
    self.infoText.text=info_ns;
}


@end

