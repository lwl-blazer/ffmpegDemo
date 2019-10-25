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
    self.title = @"编码";
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
    //打开PCM文件
    FILE *pcmFileHandle = fopen([pcmFilePath cStringUsingEncoding:NSUTF8StringEncoding], "rb");
    size_t readBufferSize = 0;

    /** fread 从文件流中读取
     * size_t fread(void *buffer, size_t size, size_t count, FILE *steam)
     * buffer 是读取的数据存放的内存的指针(可以是数组，也可以是新开辟的空间，buffer就是一个索引)
     * size 每次读取的字节数
     * count 读取的次数
     * stream 是要读取的文件的指针
     */
    while ((readBufferSize = fread(buffer, 1, bufferSize, pcmFileHandle)) > 0) {
        encoder->encode(buffer, (int)readBufferSize); //一次编码的数据
    }
    
    delete [] buffer;
    fclose(pcmFileHandle);
    encoder->destroy();
    delete encoder;
}

- (IBAction)hardwareAction:(id)sender {
    
    
    
}

@end
