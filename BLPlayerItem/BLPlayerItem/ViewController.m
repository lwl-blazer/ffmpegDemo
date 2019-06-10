//
//  ViewController.m
//  BLPlayerItem
//
//  Created by luowailin on 2019/4/19.
//  Copyright © 2019 luowailin. All rights reserved.
//   http://vfx.mtime.cn/Video/2019/04/10/mp4/190410081607863991.mp4

#import "ViewController.h"
#import "XDemux.h"
#import "XDecode.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    XDemux *demux = [[XDemux alloc] init];
    NSString *url = @"http://vfx.mtime.cn/Video/2019/04/10/mp4/190410081607863991.mp4";
    [demux open:url];
    
    XDecode *vDecode = [[XDecode alloc] init];
    [vDecode open:[demux copyVideoParameters]];
    
    XDecode *aDecode = [[XDecode alloc] init];
    [aDecode open:[demux copyAudioParameters]];
    
    while (1) {
        AVPacket *packet = [demux read];
        if ([demux isAudio:packet]) {
            [aDecode send:packet];
            AVFrame *frame = [aDecode recv];
            if (frame) {
                NSLog(@"audio recv: %s", frame->data[0]);
            }
        } else {
            [vDecode send:packet];
            AVFrame *frame = [vDecode recv];
            if (frame) {
                NSData *data = [NSData dataWithBytes:frame->data[0] length:frame->width * frame->height];
                NSLog(@"video recv: %@", data);
            }
        }
    }
}

@end
