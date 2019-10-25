//
//  AudioToolboxEncoder.h
//  FDKAACEncoder
//
//  Created by luowailin on 2019/10/25.
//  Copyright © 2019 luowailin. All rights reserved.
//
// 利用AudioToolBox进行硬编码

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@protocol FillDataDelegate <NSObject>

- (UInt32)fillAudioData:(uint8_t *)sampleBuffer bufferSize:(UInt32)bufferSize;
- (void)outputAACPacket:(NSData *)data
  presentationTimeMills:(int64_t)presentationTimeMills
                  error:(NSError *)error;
- (void)onCompletion;

@end


@interface AudioToolboxEncoder : NSObject

- (instancetype)initWithSampleRate:(NSInteger)inputSampleRate
                          channels:(int)channels
                           bitRate:(int)bitRate
                    withADTSHeader:(BOOL)withADTSHeader
                 filleDataDelegate:(id<FillDataDelegate>)fillAudioDataDelegate;

@end

NS_ASSUME_NONNULL_END
