//
//  ELAudioSession.h
//  Advance-video-play
//
//  Created by luowailin on 2019/9/11.
//  Copyright © 2019 luowailin. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

extern const NSTimeInterval AUSAudioSessionLatency_Background;
extern const NSTimeInterval AUSAudioSessionLatency_Default;
extern const NSTimeInterval AUSAudioSessionLatency_LowLatency;

NS_ASSUME_NONNULL_BEGIN

@interface ELAudioSession : NSObject

@property(nonatomic, strong) AVAudioSession *audioSession;

//根据我们需要硬件设备提供的能力来设置类别
@property(nonatomic, strong) NSString *category;

@property(nonatomic, assign) Float64 preferredSampleRate;
@property(nonatomic, assign, readonly) Float64 currentSampleRate;
@property(nonatomic, assign) NSTimeInterval preferredLatency;
@property(nonatomic, assign) BOOL active;

+ (ELAudioSession *)sharedInstance;
- (void)addRouteChangeListener;

@end

NS_ASSUME_NONNULL_END


/** AVAudioSession --- Category
 *
 * 音频会话 用于管理与获取iOS设备音频的硬件信息 获取AVAudioSession的实例之后，就可以设置以何种方式使用音频硬件做哪些处理
 * 由于iOS系统的特殊性，所有APP共用一个AVAudioSession。所以这个会话是单例对象
 *
 * Category -- 能解决音频开发的各种播放被打断或者首次启动时无声音的问题
 *
 * 当遇到'插拔耳机','接电话','调起siri'...哪些行为表现:
    .进行录音还是播放
    .当系统静音键接下时该如何表现
    .是从扬声器还是从听筒面播放声音
    .插拔耳机后的表现
    .来电话/闹钟响了后如何表现
    .其他音频App启动后如何表现
 *
 * 默认行为表现: ----- AVAudioSessionCategorySoloAmbient
    .可以进行播放，但是不能进行录制。
    .当用户将手机上的静音拨片拨到“静音”状态时，此时如果正在播放音频，那么播放内容会被静音。
    .当用户按了手机的锁屏键或者手机自动锁屏了，此时如果正在播放音频，那么播放会静音并被暂停。
    .如果你的App在开始播放的时候，此时QQ音乐等其他App正在播放，那么其他播放器会被静音并暂停。
 *
 *
 * 激活:
     - (BOOL)setActive:(BOOL)active error:(NSError **)outError;
 *
 *
 * 七大场景 Category
   .AVAudioSessionCategoryAmbient:只用于播放音乐时，并且可以和QQ音乐同时播放，比如玩游戏的时候还想听QQ音乐的歌，那么把游戏播放背景音就设置成这种类别。同时，当用户锁屏或者静音时也会随着静音，这种类别基本使用所有App的背景场景。
 
       .AVAudioSessionCategoryAudioProcessing:主要用于音频格式处理，一般可以配合AudioUnit进行使用.
 
       .AVAudioSessionCategoryMultiRoute:想象一个DJ用的App，手机连着HDMI到扬声器播放当前的音乐，然后耳机里面播放下一曲，这种常人不理解的场景，这个类别可以支持多个设备输入输出.
 
       .AVAudioSessionCategoryPlayAndRecord: 如果既想播放又想录制该用什么模式呢？比如VoIP，打电话这种场景，PlayAndRecord就是专门为这样的场景设计的.
 
       .AVAudioSessionCategoryPlayback:如果锁屏了还想听声音怎么办？用这个类别，比如App本身就是播放器，同时当App播放时，其他类似QQ音乐就不能播放了。所以这种类别一般用于播放器类App.
 
    .AVAudioSessionCategoryRecord:有了播放器，肯定要录音机，比如微信语音的录制，就要用到这个类别，既然要安静的录音，肯定不希望有QQ音乐了，所以其他播放声音会中断。想想微信语音的场景，就知道什么时候用他了.
 
    .AVAudioSessionCategorySoloAmbient:也是只用于播放,但是和AVAudioSessionCategoryAmbient不同的是，用了它就别想听QQ音乐了，比如不希望QQ音乐干扰的App，类似节奏大师。同样当用户锁屏或者静音时也会随着静音，锁屏了就玩不了节奏大师了.
 *
 * 除了上面的七大主场景外，还可以设置主场景下的模式
      - (BOOL)setCategory:(NSString *)category withOptions:(AVAudioSessionCategoryOptions)options error:(NSError **)outError;
 * AVAudioSessionCategoryOptions模式:
     具体的请参考网址
 * https://www.sunyazhou.com/2018/01/12/20180112AVAudioSession-Category/
 */
