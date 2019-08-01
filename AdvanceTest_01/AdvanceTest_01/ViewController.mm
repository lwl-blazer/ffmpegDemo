//
//  ViewController.m
//  AdvanceTest_01
//
//  Created by luowailin on 2019/7/29.
//  Copyright © 2019 luowailin. All rights reserved.
//  https://github.com/zhanxiaokai

#import "ViewController.h"
#import "CommonUtil.h"
#import "Mp3Encoder.hpp"
#import "accompany_decoder_controller.hpp"

@interface ViewController ()
@property (weak, nonatomic) IBOutlet UILabel *pathLabel;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
}

- (IBAction)encode:(id)sender {
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        Mp3Encoder *encoder = new Mp3Encoder();
        const char *pcmFilePath = [[CommonUtil bundlePath:@"test" type:@"pcm"] cStringUsingEncoding:NSUTF8StringEncoding];
        const char *mp3FilePath = [[CommonUtil documentsPath:@"vocal.mp3"] cStringUsingEncoding:NSUTF8StringEncoding];
        NSLog(@"%s", mp3FilePath);
        int sampleRate = 44100;
        int channels = 2;
        int bitRate = 128 * 1024;
        NSLog(@"start");
        encoder->Init(pcmFilePath, mp3FilePath, sampleRate, channels, bitRate);
        encoder->Encode();
        encoder->Destory();
        
        delete encoder;
        NSLog(@"success");
    });
}

- (IBAction)separateAction:(id)sender {
    NSLog(@"decode Test...");
    //由于我们在iOS平台编译的ffmpeg 没有打开mp3的decoder开关，但是打开了aac的 所以这里使用aac来做测试
    const char* mp3FilePath = [[CommonUtil bundlePath:@"131" type:@"aac"] cStringUsingEncoding:NSUTF8StringEncoding];
    const char *pcmFilePath = [[CommonUtil documentsPath:@"131.pcm"] cStringUsingEncoding:NSUTF8StringEncoding];
    printf("%s\n", pcmFilePath);
    AccompanyDecoderController* decoderController = new AccompanyDecoderController();
    decoderController->Init(mp3FilePath, pcmFilePath);
    decoderController->Decode();
    decoderController->Destroy();
    delete decoderController;
    NSLog(@"After decode Test...");
}

- (IBAction)aac2pcmAction:(id)sender {
    
    
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event{
    NSLog(@"touch");
}

@end
