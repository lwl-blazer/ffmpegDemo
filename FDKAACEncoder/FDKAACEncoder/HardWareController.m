//
//  HardWareController.m
//  FDKAACEncoder
//
//  Created by luowailin on 2019/10/25.
//  Copyright © 2019 luowailin. All rights reserved.
//

#import "HardWareController.h"
#import "AudioToolboxEncoder.h"
#import "CommonUtil.h"

@interface HardWareController ()<FillDataDelegate>

@property(nonatomic, strong) AudioToolboxEncoder *encoder;
@property(nonatomic, copy) NSString *pcmFilePath;
@property(nonatomic, copy) NSString *aacFilePath;

@property(nonatomic, strong) NSFileHandle *aacFileHandle;
@property(nonatomic, strong) NSFileHandle *pcmFileHandle;

@property(nonatomic, assign) double startEncodeTimeMills;

@end

@implementation HardWareController

- (void)viewDidLoad {
    [super viewDidLoad];
}


- (IBAction)encoderAction:(id)sender {
    
    self.pcmFilePath = [CommonUtil bundlePath:@"recorder"
                                         type:@"pcm"]; /*[[NSBundle mainBundle] pathForResource:@"recorder"
                                                   ofType:@"pcm"];*/
    self.pcmFileHandle = [NSFileHandle fileHandleForReadingAtPath:self.pcmFilePath];
    
    self.aacFilePath = [CommonUtil documentsPath:@"encoder.aac"]; /*[[NSBundle mainBundle] pathForResource:@"hardwareEncoder"
                                                       ofType:@"aac"];*/
    NSLog(@"%@", self.aacFilePath);
    [[NSFileManager defaultManager] removeItemAtPath:self.aacFilePath
                                               error:nil];
    [[NSFileManager defaultManager] createFileAtPath:self.aacFilePath contents:nil attributes:nil];
    self.aacFileHandle = [NSFileHandle fileHandleForWritingAtPath:self.aacFilePath];
    
    NSInteger sampleRate = 44100;
    int channels = 2;
    int bitRate = 128 * 1024;
    
    self.startEncodeTimeMills = CFAbsoluteTimeGetCurrent() * 1000;
    self.encoder = [[AudioToolboxEncoder alloc] initWithSampleRate:sampleRate
                                                          channels:channels
                                                           bitRate:bitRate
                                                    withADTSHeader:YES
                                                 filleDataDelegate:self];

}

#pragma mark FillDataDelegate

- (UInt32)fillAudioData:(uint8_t *)sampleBuffer
             bufferSize:(UInt32)bufferSize{
    UInt32 ret = 0;
    NSData *data = [self.pcmFileHandle readDataOfLength:bufferSize];
    if (data && data.length) {
        memcpy(sampleBuffer, data.bytes, data.length);
        ret = (UInt32)data.length;
    }
    return ret;
}

- (void)outputAACPacket:(NSData *)data presentationTimeMills:(int64_t)presentationTimeMills error:(NSError *)error{
    if (nil == error) {
        [self.aacFileHandle writeData:data];
    } else {
        NSLog(@"Output AAC Packet return Error:%@", error);
    }
}


- (void)onCompletion{
    int wasteTimeMills = CFAbsoluteTimeGetCurrent() *1000 - self.startEncodeTimeMills;
    NSLog(@"Encode AAC Waste TimeMills is %d", wasteTimeMills);
    [self.aacFileHandle closeFile];
    self.aacFileHandle = NULL;
}

@end
