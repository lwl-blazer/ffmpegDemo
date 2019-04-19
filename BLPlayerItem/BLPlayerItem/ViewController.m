//
//  ViewController.m
//  BLPlayerItem
//
//  Created by luowailin on 2019/4/19.
//  Copyright © 2019 luowailin. All rights reserved.
//

#import "ViewController.h"
#import "XDemux.h"


@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    XDemux *demux = [[XDemux alloc] init];
    [demux open:@"http://vfx.mtime.cn/Video/2019/04/10/mp4/190410081607863991.mp4"];
}


@end
