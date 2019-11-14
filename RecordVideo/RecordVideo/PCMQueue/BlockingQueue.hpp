//
//  BlockingQueue.hpp
//  RecordVideo
//
//  Created by luowailin on 2019/11/13.
//  Copyright © 2019 luowailin. All rights reserved.
//

#ifndef BlockingQueue_hpp
#define BlockingQueue_hpp

#include <stdio.h>
#include <pthread.h>

typedef struct AudioPacket {
    short *buffer;
    int size;
    AudioPacket(){
        buffer = nullptr;
        size = 0;
    }
    
    ~AudioPacket(){
        if (nullptr != buffer) {
            delete [] buffer;
            buffer = nullptr;
        }
    }
} AudioPacket;

typedef struct AudioPacketList{
    AudioPacket *pkt;
    struct AudioPacketList *next;
    AudioPacketList(){
        pkt = nullptr;
        next = nullptr;
    }
} AudioPacketList;

/**阻塞队列 -- 解决生产者-消费者模式的经典用法*/
class BlockingQueue {
    
    AudioPacketList *audioLists;
    AudioPacketList *mFirst;
    AudioPacketList *mLast;
    
    pthread_mutex_t mLock;
    pthread_cond_t mCondition;
    
    bool mAbortRequest;
    int mNbPackets;
public:
    BlockingQueue();
    ~BlockingQueue();
    
    //入队列
    int put(AudioPacket *audioPacket);
    //出队列
    int get(AudioPacket **audioPacket, bool block);
    //销毁队列
    void flush();
    
    void abort();
    
};


#endif /* BlockingQueue_hpp */
