//
//  packet_queue.cpp
//  AudioPlayer
//
//  Created by luowailin on 2019/8/5.
//  Copyright © 2019 luowailin. All rights reserved.
//

#include "packet_queue.hpp"
#define LOG_TAG "SongStudioPacketQueue"

PacketQueue::PacketQueue(){
    init();
}

PacketQueue::PacketQueue(const char *queueNameParam){
    init();
    queueName = queueNameParam;
}

void PacketQueue::init(){
    int initLockCode = pthread_mutex_init(&mLock, nullptr);
    LOGI("initLockCode is %d", initLockCode);
    
    int initConditionCode = pthread_cond_init(&mCondition, nullptr);
    LOGI("initConditionCode is %d", initConditionCode);
    
    mNbPackets = 0;
    mFirst = nullptr;
    mLast = nullptr;
    mAbortRequest = false;
}


PacketQueue::~PacketQueue(){
    LOGI("%s ~PacketQueue", queueName);
    flush();
    pthread_mutex_destroy(&mLock);
    pthread_cond_destroy(&mCondition);
}

int PacketQueue::size(){
    pthread_mutex_lock(&mLock);
    int size = mNbPackets;
    pthread_mutex_unlock(&mLock);
    return size;
}


void PacketQueue::flush(){
    LOGI("%s flush .... and this time the queue size is %d", queueName, size());
    AudioPacketList *pkt, *pkt1;
    AudioPacket *audioPacket;
    
    pthread_mutex_lock(&mLock);
    for (pkt = mFirst; pkt != nullptr; pkt = pkt1) {
        pkt1 = pkt->next;
        audioPacket = pkt->pkt;
        if (audioPacket != nullptr) {
            delete audioPacket;
        }
        
        delete pkt;
        pkt = nullptr;
    }
    
    mLast = nullptr;
    mFirst = nullptr;
    mNbPackets = 0;
    pthread_mutex_unlock(&mLock);

}

int PacketQueue::put(AudioPacket *audioPacket){
    if (mAbortRequest) {
        delete audioPacket;
        return -1;
    }
    
    AudioPacketList *pkt1 = new AudioPacketList();
    if (!pkt1) {
        return -1;
    }
    
    pkt1->pkt = audioPacket;
    pkt1->next = nullptr;
    
    int getLockCode = pthread_mutex_lock(&mLock);
    LOGI("%s get pthread_mutex_lock result in put method:  %d", queueName, getLockCode);
    
    if (mLast == nullptr) {
        mFirst = pkt1;
    } else {
        mLast->next = pkt1;
    }
    
    mLast = pkt1;
    mNbPackets ++;

    pthread_cond_signal(&mCondition);
    pthread_mutex_unlock(&mLock);
    
    return 0;
}

int PacketQueue::get(AudioPacket **audioPacket, bool block){
    AudioPacketList *pkt1;
    int ret;
    
    int getLockCode = pthread_mutex_lock(&mLock);
    LOGI("%s get pthread_mutex_lock result in get method:  %d", queueName, getLockCode);
    
    for (;;) {
        if (mAbortRequest) {
            ret = -1;
            break;
        }
        
        pkt1 = mFirst;
        if (pkt1) {
            mFirst = pkt1->next;
            if (!mFirst) {
                mLast = nullptr;
            }
            mNbPackets--;
            *audioPacket = pkt1->pkt;
            delete pkt1;
            pkt1 = nullptr;
            ret = 1;
            break;
        } else if (!block) {
            ret = 0;
            break;
        } else {
            pthread_cond_wait(&mCondition, &mLock);
        }
    }
    
    pthread_mutex_unlock(&mLock);
    return ret;
}

void PacketQueue::abort(){
    pthread_mutex_lock(&mLock);
    mAbortRequest = true;
    pthread_cond_signal(&mCondition);
    pthread_mutex_unlock(&mLock);
}
