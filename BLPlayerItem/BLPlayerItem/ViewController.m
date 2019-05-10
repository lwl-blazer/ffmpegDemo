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

@interface ViewController ()

@property (weak, nonatomic) IBOutlet UITextField *urlField;
@property (weak, nonatomic) IBOutlet UISlider *progressSlide;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
}

- (IBAction)runButtonAction:(id)sender {
    XDemux *demux = [[XDemux alloc] init];
    //[demux open:@"http://vfx.mtime.cn/Video/2019/04/10/mp4/190410081607863991.mp4"];
    [demux open:[[NSBundle mainBundle] pathForResource:@"testVideo-1" ofType:@"mp4"]];
    
    XDecode *vdecode = [[XDecode alloc] init];
    [vdecode open:[demux copyVideoParameters]];
    
    XDecode *adecode = [[XDecode alloc] init];
    [adecode open:[demux copyAudioParameters]];
    
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
                    NSLog(@"video:%lld", frame->pkt_dts);
                    av_frame_free(&frame);
                } else {
                    NSLog(@"video ------");
                }
            }
        }
        
        if (!pkt) {
            break;
        }
    }
    NSLog(@"==================end================");
}


- (IBAction)slideAction:(id)sender {
    
}






@end
