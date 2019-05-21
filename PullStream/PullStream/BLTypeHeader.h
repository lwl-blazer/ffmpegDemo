
//
//  BLTypeHeader.h
//  PullStream
//
//  Created by luowailin on 2019/5/21.
//  Copyright © 2019 luowailin. All rights reserved.
//

#ifndef BLTypeHeader_h
#define BLTypeHeader_h


#pragma pack(push, 1) //字节对齐 为1

typedef struct {
    int data : 24;
} int24_t;

typedef struct {
    int24_t timestamp;
    int24_t msg_length;
    int8_t msg_type_id;
    int msg_stream_id;
} RTMPChunk_0;

typedef struct {
    int24_t delta;
    int24_t msg_length;
    int8_t  msg_type_id;
} RTMPChunk_1;


typedef struct {
    int24_t delta;
} RTMPChunk_2;

#define RTMP_CHUNK_TYPE_0 0x00 //12字节
#define RTMP_CHUNK_TYPE_1 0x40 //8字节
#define RTMP_CHUNK_TYPE_2 0x80 //4字节
#define RTMP_CHUNK_TYPE_3 0xC0 //1字节

#pragma pack(pop)//恢复字节对齐

typedef NS_ENUM(NSUInteger, LLYStreamID) {
    LLYStreamIDPing   = 0x02,//Ping 和ByteRead通道
    LLYStreamIDInvoke = 0x03,//invoke通道,connect,publish,connect
    LLYStreamIDAudio  = 0x04,//audio or video,这里只作为音频数据
    LLYStreamIDVideo  = 0x06, //video //官方文档保留,实际可以发送视音频数据
    LLYStreamIDPlay = 0x08 // 播放
};

typedef NS_ENUM(NSUInteger, LLYMSGTypeID) {
    LLYMSGTypeID_CHUNK_SIZE   = 0x1,
    LLYMSGTypeID_BYTES_READ   = 0x3,
    LLYMSGTypeID_PING         = 0x4,
    LLYMSGTypeID_SERVER_WINDOW= 0x5,
    LLYMSGTypeID_PEER_BW      = 0x6,
    LLYMSGTypeID_AUDIO        = 0x8,
    LLYMSGTypeID_VIDEO        = 0x9,
    LLYMSGTypeID_FLEX_STREAM  = 0xF,
    LLYMSGTypeID_FLEX_OBJECT  = 0x10,
    LLYMSGTypeID_FLEX_MESSAGE = 0x11,
    LLYMSGTypeID_NOTIFY       = 0x12,
    LLYMSGTypeID_SHARED_OBJ   = 0x13,
    LLYMSGTypeID_INVOKE       = 0x14,
    LLYMSGTypeID_METADATA     = 0x16,
};

typedef NS_ENUM(NSUInteger, RTMP_HEADER_TYPE) {
    RTMP_HEADER_TYPE_FULL              = 0x0, // RTMPChunk_0
    RTMP_HEADER_TYPE_NO_MSG_STREAM_ID  = 0x1, // RTMPChunk_1
    RTMP_HEADER_TYPE_TIMESTAMP         = 0x2, // RTMPChunk_2
    RTMP_HEADER_TYPE_ONLY              = 0x3, // no chunk header
};

typedef NS_ENUM(NSUInteger, AMF_DATA_TYPE) {
    AMF_DATA_TYPE_NUMBER      = 0x00,
    AMF_DATA_TYPE_BOOL        = 0x01,
    AMF_DATA_TYPE_STRING      = 0x02,
    AMF_DATA_TYPE_OBJECT      = 0x03,
    AMF_DATA_TYPE_NULL        = 0x05,
    AMF_DATA_TYPE_UNDEFINED   = 0x06,
    AMF_DATA_TYPE_REFERENCE   = 0x07,
    AMF_DATA_TYPE_MIXEDARRAY  = 0x08,
    AMF_DATA_TYPE_OBJECT_END  = 0x09,
    AMF_DATA_TYPE_ARRAY       = 0x0a,
    AMF_DATA_TYPE_DATE        = 0x0b,
    AMF_DATA_TYPE_LONG_STRING = 0x0c,
    AMF_DATA_TYPE_UNSUPPORTED = 0x0d,
};

typedef NS_ENUM(NSUInteger, FLV_TAG_TYPE) {
    FLV_TAG_TYPE_AUDIO  = 0x08,
    FLV_TAG_TYPE_VIDEO  = 0x09,
    FLV_TAG_TYPE_META   = 0x12,
    FLV_TAG_TYPE_INVOKE = 0x14
};

typedef NS_ENUM(NSUInteger, FLV_CODECID) {
    FLV_CODECID_H263    = 2,
    FLV_CODECID_SCREEN  = 3,
    FLV_CODECID_VP6     = 4,
    FLV_CODECID_VP6A    = 5,
    FLV_CODECID_SCREEN2 = 6,
    FLV_CODECID_H264    = 7,
};

#define FLV_VIDEO_FRAMETYPE_OFFSET   4
typedef NS_ENUM(NSUInteger,  FLV_FRAME) {
    FLV_FRAME_KEY        = 1 << FLV_VIDEO_FRAMETYPE_OFFSET,
    FLV_FRAME_INTER      = 2 << FLV_VIDEO_FRAMETYPE_OFFSET,
    FLV_FRAME_DISP_INTER = 3 << FLV_VIDEO_FRAMETYPE_OFFSET,
    
};

#endif /* BLTypeHeader_h */
