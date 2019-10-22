//
//  ViewController.m
//  FDKAACEncoder
//
//  Created by luowailin on 2019/10/21.
//  Copyright © 2019 luowailin. All rights reserved.
//

#import "ViewController.h"
#include <stdio.h>
#import "Audio_encoder.hpp"
#import "CommonUtil.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    if (@available(iOS 13.0, *)) {
        self.view.backgroundColor = [UIColor colorWithDynamicProvider:^UIColor * _Nonnull(UITraitCollection * _Nonnull traitCollection) {
            return [UIColor redColor];
        }];
    } else {
        self.view.backgroundColor = [UIColor redColor];
    }
}

- (IBAction)encodeAction:(UIButton *)sender {
    
    NSString *pcmFilePath = [CommonUtil bundlePath:@"recorder" type:@"pcm"];
    NSString *aacFilePath = [CommonUtil documentsPath:@"test.aac"];
    
    AudioEncoder *encoder = new AudioEncoder();
    int bitsPerSample = 16;
    const char *codec_name = [@"aac" cStringUsingEncoding:NSUTF8StringEncoding];
    int bitRate = 128 * 1024;
    int channels = 2;
    int sampleRate = 44100;
    int ret = encoder->init(bitRate, channels, sampleRate, bitsPerSample, [aacFilePath cStringUsingEncoding:NSUTF8StringEncoding], codec_name);
    if (ret < 0) {
        NSLog(@"init encoder error");
        return;
    }
    
    
    int bufferSize = 1024 * 256;
    byte *buffer = new byte[bufferSize];
    
    FILE *pcmFileHandle = fopen([pcmFilePath cStringUsingEncoding:NSUTF8StringEncoding], "rb");
    size_t readBufferSize = 0;

    while ((readBufferSize = fread(buffer, 1, bufferSize, pcmFileHandle)) > 0) {
        encoder->encode(buffer, (int)readBufferSize);
    }
    
    delete [] buffer;
    fclose(pcmFileHandle);
    encoder->destroy();
    delete encoder;
}


@end
