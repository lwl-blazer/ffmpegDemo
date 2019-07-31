//
//  ViewController.m
//  AdvanceTest_01
//
//  Created by luowailin on 2019/7/29.
//  Copyright © 2019 luowailin. All rights reserved.
//

#import "ViewController.h"
#import "Mp3Encoder.hpp"
//https://github.com/zhanxiaokai

@interface ViewController ()
@property (weak, nonatomic) IBOutlet UILabel *pathLabel;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
}

- (IBAction)encode:(id)sender {
    NSString *path = [[NSBundle mainBundle] pathForResource:@"test" ofType:@"pcm"];
    
    NSString *doc = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
    doc = [doc stringByAppendingPathComponent:@"vocal.mp3"];
    NSLog(@"%@", doc);
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        Mp3Encoder *encoder = new Mp3Encoder();
        if (encoder->Init([path UTF8String], [doc UTF8String], 44100, 2, 312000) == 0) {
            encoder->Encode();
            encoder->Destory();
        }
        delete encoder;
    });
}

- (void)didReceiveMemoryWarning{
    
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event{
    NSLog(@"touch");
}

@end
