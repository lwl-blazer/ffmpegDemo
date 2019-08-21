//
//  AudioPlayer.m
//  AudioPlayer
//
//  Created by luowailin on 2019/8/5.
//  Copyright © 2019 luowailin. All rights reserved.
//

#import "AudioPlayer.h"
#import "AudioOutput.h"
#import "accompany_decoder_controller.hpp"

@interface AudioPlayer ()<FillDataDelegate>
{
    AudioOutput *_audioOutput;
    AccompanyDecoderController *_decoderController;
}
@end

@implementation AudioPlayer

- (instancetype)initWithFilePath:(NSString *)filePath{
    self = [super init];
    if (self) {
        //初始化解码模块，并且从解码模块中取出原始数据
        _decoderController = new AccompanyDecoderController();
        _decoderController->init([filePath cStringUsingEncoding:NSUTF8StringEncoding], 0.2f);
        
        NSInteger channels = _decoderController->getChannels();
        NSInteger sampleRate = _decoderController->getAudioSampleRate();
        NSInteger bytesPersample = 2;
        _audioOutput = [[AudioOutput alloc] initWithChannels:channels
                                                  sampleRate:sampleRate
                                              bytesPerSample:bytesPersample
                                           filleDataDelegate:self];
    }
    return self;
}

- (void)start{
    if (_audioOutput) {
        [_audioOutput play];
    }
}

- (void)stop{
    if (_audioOutput) {
        [_audioOutput stop];
        _audioOutput = nil;
    }
    
    if (_decoderController != NULL) {
        _decoderController->destroy();
        delete _decoderController;
        _decoderController = NULL;
    }
}

- (NSInteger)fillAudioData:(SInt16 *)sampleBuffer numFrames:(NSInteger)frameNum numChannels:(NSInteger)channels{
    //默认填充空数据
    memset(sampleBuffer, 0, frameNum * channels *sizeof(SInt16));
    if (_decoderController) {
        //从decoderController中取出数据，然后填充进去
        _decoderController->readSamples(sampleBuffer, (int)(frameNum *channels));
    }
    return 1;
}

@end
