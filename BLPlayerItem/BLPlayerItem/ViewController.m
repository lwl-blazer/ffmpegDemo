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
#import "PlayView.h"

@interface ViewController ()<GLKViewDelegate>

@property (weak, nonatomic) IBOutlet UITextField *urlField;
@property (weak, nonatomic) IBOutlet UISlider *progressSlide;
@property (weak, nonatomic) IBOutlet PlayView *playView;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    XDemux *demux = [[XDemux alloc] init];
    [demux open:@"http://vfx.mtime.cn/Video/2019/04/10/mp4/190410081607863991.mp4"];
    //[demux open:@"testVideo-1.mp4"];
    
    XDecode *vdecode = [[XDecode alloc] init];
    [vdecode open:[demux copyVideoParameters]];
    
    XDecode *adecode = [[XDecode alloc] init];
    [adecode open:[demux copyAudioParameters]];
    
    while (YES) {
        AVPacket *pkt = [demux read];
        if ([demux isAudio:pkt]) {
            [adecode send:pkt];
            AVFrame *frame = [adecode recv];
            
            NSLog(@"audio:%f", frame->pkt_dts);
        } else {
            if ([vdecode send:pkt]) {
                AVFrame *frame = [vdecode recv];
                NSLog(@"video:%lld", frame->pkt_dts);
            }
            
        }
        
        if (!pkt) {
            break;
        }
    }
}

- (IBAction)runButtonAction:(id)sender {
    
}


- (IBAction)slideAction:(id)sender {
    
}






@end
