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
        _decoderController = new AccompanyDecoderController();
        
    }
    return self;
}


@end
