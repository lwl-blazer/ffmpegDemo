//
//  ViewController.m
//  BLPlayerItem
//
//  Created by luowailin on 2019/4/19.
//  Copyright © 2019 luowailin. All rights reserved.
//

#import "ViewController.h"
#import "XDemux.h"
#import "XDecode.h"
#import "DecodeObject.h"

@interface ViewController (){
    FILE *file_YUV;
}

@property (weak, nonatomic) IBOutlet UITextField *urlField;
@property (weak, nonatomic) IBOutlet UISlider *progressSlide;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    /*char output_str_full[500]={0};
    NSString *myout = @"521_720x576";
    NSString *output_str= [NSString stringWithFormat:@"%@.yuv",myout];
    NSString *output_nsstr=[[[NSBundle mainBundle]resourcePath] stringByAppendingPathComponent:output_str];
    sprintf(output_str_full,"%s",[output_nsstr UTF8String]);
    printf("Output Path:%s\n",output_str_full);
    
    file_YUV = fopen(output_str_full,"wb+");
    if(file_YUV == NULL){
        printf("Cannot open output file_YUV.\n");
    }
    */
}

- (IBAction)runButtonAction:(id)sender {
    /*
    XDemux *demux = [[XDemux alloc] init];
    //[demux open:@"http://vfx.mtime.cn/Video/2019/04/10/mp4/190410081607863991.mp4"];
    //[demux open:[[NSBundle mainBundle] pathForResource:@"testVideo-1" ofType:@"mp4"]];
    [demux open:[[NSBundle mainBundle] pathForResource:@"521" ofType:@"flv"]];
    
    XDecode *vdecode = [[XDecode alloc] init];
    [vdecode open:[demux copyVideoParameters]];
    
    XDecode *adecode = [[XDecode alloc] init];
    [adecode open:[demux copyAudioParameters]];
    
    int frame_cnt = 0;
    while (YES) {
        AVPacket *pkt = [demux read];
        if ([demux isAudio:pkt]) {
            [adecode send:pkt];
            AVFrame *frame = [adecode recv];
            if (frame) {
                NSLog(@"audio:%lld", frame->pkt_dts);
                av_frame_free(&frame);
            } else {
                NSLog(@"audio ------");
            }
        } else {
            if ([vdecode send:pkt]) {
                AVFrame *frame = [vdecode recv];
                if (frame) {
                    //NSLog(@"video:%lld", frame->pkt_dts);
                    
                    if (file_YUV) {
                        int y_size = demux.width * demux.height;
                        fwrite(frame->data[0], 1,y_size,  file_YUV);    //Y
                        fwrite(frame->data[1], 1,y_size/4, file_YUV);  //U
                        fwrite(frame->data[2], 1,y_size/4, file_YUV);  //V
                        
                        //Output info
                        char pictype_str[10]={0};
                        switch(frame->pict_type){
                            case AV_PICTURE_TYPE_I:sprintf(pictype_str,"I");break;
                            case AV_PICTURE_TYPE_P:sprintf(pictype_str,"P");break;
                            case AV_PICTURE_TYPE_B:sprintf(pictype_str,"B");break;
                            default:sprintf(pictype_str,"Other");break;
                        }
                        
                        frame_cnt ++;
                        NSLog(@"解码序号%d,Type:%s", frame_cnt, pictype_str);
                    }
                    
                    av_frame_free(&frame);
                }
            }
        }
        
        if (!pkt) {
            break;
        }
        
    }
    NSLog(@"==================end================");*/
    
    DecodeObject *object = [[DecodeObject alloc] init];
    [object decodeWithTwoUrl:@"521.flv"];
}


- (IBAction)slideAction:(id)sender {
    
}






@end
