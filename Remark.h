//
//  Remark.h
//  Kamera
//
//  Created by blazer on 2019/4/3.
//  Copyright © 2019 Bob McCune. All rights reserved.
//

#ifndef Remark_h
#define Remark_h

/** 配置录音会话键值信息 <AVFoundation/ AVAudioSettings.h>中
 *  AVFormatIDKey --- 写入内容的音频格式
 *      kAudioFormatLinearPCM -----  将未压缩的音频流写入到文件中
 kAudioFormatMPEG4AAC
 kAudioFormatAppleLossless
 kAudioFormatAppleIMA4
 kAudioFormatiLBC
 kAudioFormatULaw
 * 假如选择AAC(kAudioFormatMPEG4AAC 或 kAudioFormatAppleIMA4)
 * 还需要和保存的文件名后缀名一样  比如 xxx.wav  只能对应 kAudioFormatLinearPCM
 *
 * 名词解释--维基百科(音频文件格式):
 * 一般获取音频数据的方法是:采用固定的时间间隔，对音频电压采样(量化)，并将结果以某种分辨率(例如:CDDA每个采样为16比特或2字节)存储。采样的时间间隔可以有不同的标准(如CDDA采用每秒44100次 DVD采用每秒48000或96000次). 因此采样率、分辨率和声道数目是音频文件格式的关键参数
 *
 * 主要的音频文件格式:
 无损格式     WAV, FLAC, APE, ALAC, WacPack
 有损格式     MP3, AAC, Ogg Vorbis, Opus    -----有损文件格式是基于声学心理学模型
 */

/** 采样率
 * AVSampleRateKey
 *
 * 采样率定义了对输入的模拟音频信号每一秒内的采样数
 *
 * 标准的采样率:  8000 , 16000 , 22050 或 44100
 */

/** 通道数
 * AVNumberOfChannelsKey
 *
 * 1 指定默认值1意味着使用单声道录制   2---立体声录制
 */








#endif /* Remark_h */
