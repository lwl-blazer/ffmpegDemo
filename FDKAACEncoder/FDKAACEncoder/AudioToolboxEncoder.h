//
//  AudioToolboxEncoder.h
//  FDKAACEncoder
//
//  Created by luowailin on 2019/10/25.
//  Copyright © 2019 luowailin. All rights reserved.
//
// 利用AudioToolBox下的Audio Converter Services进行硬编码
/** Audio Converter Services --- 转换服务
 * PCM到PCM
 * 转换位深度
 * 采样率
 * 表示格式，也包括交错存储还是平铺存储，与FFmpeg里的重采样器非常类似，
 * 最重要的是还可以做PCM到压缩格式的转换，所谓转换，在这种场景下其实就是可以做编码或者解码操作。
 * 此例利用Audio Converter Services所提供的编码服务、将PCM数据编码为AAC格式的数据
 *
 */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@protocol FillDataDelegate <NSObject>
//当编码器(或者说转换器)需要编码一段PCM数据的时候，就通过该方法来调用客户端代码，让实现该Delegate的客户端来填充PCM数据
- (UInt32)fillAudioData:(uint8_t *)sampleBuffer bufferSize:(UInt32)bufferSize;
//编码器成功编码一段AAC的Packet之后，添加完ADTS头信息，然后调用该方法，进行输出数据
- (void)outputAACPacket:(NSData *)data
  presentationTimeMills:(int64_t)presentationTimeMills
                  error:(NSError *)error;
//编码器结束之后，调用
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

/**
 * PCM编码(脉冲代码调制编码)
 * PCM通过抽样、量化、编码三个步骤将连续变化的模拟信号转换为数字编码
 *  1.抽样:
 *    对模拟信号进行周期性扫描，把时间上连续的信号变成时间上离散的信号
 *  2.量化:
 *    用一组规定的电平，把瞬时抽样值用最接近的电平值来表示，通常用二进制表示
 *  3.编码:
 *    用一组二进制码组来表示每一个有固定电平的量化值
 *
 * AAC高级音频编码
 *   --- 基于MPEG-2的音频编码技术 目的是取代MP3格式
 *
 *   AAC是新一代音频有损压缩格式，它通过一些附加的编码技术(PS、SBR)衍生出LC-AAC、HE-AAC、HE-AAC v2三种主要的编码格式
 *   LC-AAC 是比较传统的AAC，相对而言，其主要应用于中高码率场景的编码(>=80kbit/s); HE-AAC相当于(AAC+SBR)主要应用于中低码率场景的编码(<=80kKbit/s); HE-AAC v2 主要应用于低码率场景的编码(<=48Kbit/s);事实上大部分编码器都设置为<=48Kbit/s自动启运PS技术，
 *
 *
 * AAC音频格式:
 *  1.ADIF:
 *     Audio Data interchange Format 音频数据交换格式。这种格式的特征是可以确定的找到这个音频数据的开始，不需进行在音频数据中间开始的解码，即它的解码必须在明确定义的开始处进行，故这种格式常用在磁盘文件中
 *  2.ADTS:
 *     Audio Data Transport Stream 音频数据传输流    这种格式的特征是它有一个同步字的比特流，解码可以在这个流中任何位置开始。它的特征类似于MP3数据流格式
 *
 *
 *
 **/
