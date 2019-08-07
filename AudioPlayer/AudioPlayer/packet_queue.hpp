//
//  packet_queue.hpp
//  AudioPlayer
//
//  Created by luowailin on 2019/8/5.
//  Copyright © 2019 luowailin. All rights reserved.
//

#ifndef packet_queue_hpp
#define packet_queue_hpp

#include <stdio.h>
#include <pthread.h>
#include <string.h>

#define byte uint8_t
#define MAX(a, b) (((a) > (b)) ? (a) : (b))
#define MIN(a, b) (((a) < (b)) ? (a) : (b))
#define LOGI(...)  printf("  ");printf(__VA_ARGS__); printf("\t -  <%s> \n", LOG_TAG);

typedef struct AudioPacket{
    static const int AUDIO_PACKET_ACTION_PLAY = 0;
    static const int AUDIO_PACKET_ACTION_APUSE = 100;
    static const int AUDIO_PACKET_ACTION_SEEK = 101;
    
    short *buffer;
    int size;
    float position;
    int action;
    
    float extra_param1;
    float extra_param2;
    
    AudioPacket(){
        buffer = nullptr;
        size = 0;
        position = -1;
        action = 0;
        extra_param1 = 0;
        extra_param2 = 0;
    }
    
    ~AudioPacket(){
        if (buffer != nullptr) {
            delete [] buffer;
            buffer = nullptr;
        }
    }
}AudioPacket;

typedef struct AudioPacketList {
    AudioPacket *pkt;
    struct AudioPacketList *next;
    AudioPacketList() {
        pkt = nullptr;
        next = nullptr;
    }
}AudioPacketList;

inline void buildPacketFromBuffer(AudioPacket *audioPacket, short *samples, int sampleSize) {
    short *packetBuffer = new short[sampleSize];
    if (packetBuffer != nullptr) {
        memcpy(packetBuffer, samples, sampleSize * 2);
        audioPacket->buffer = packetBuffer;
        audioPacket->size = sampleSize;
    } else {
        audioPacket->size = sampleSize;
    }
}


class PacketQueue {
public:
    PacketQueue();
    PacketQueue(const char *queueNameParam);
    ~PacketQueue();
    
    void init();
    void flush();
    int put(AudioPacket *audioPacket);
    
    int get(AudioPacket **audioPacket, bool block);
    
    int size();
    void abort();
    
    
private:
    AudioPacketList *mFirst;
    AudioPacketList *mLast;
    
    int mNbPackets;
    bool mAbortRequest;
    pthread_mutex_t mLock;
    pthread_cond_t mCondition;
    const char *queueName;
};


#endif /* packet_queue_hpp */
