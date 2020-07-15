//
//  BlockingQueue.cpp
//  RecordVideo
//
//  Created by luowailin on 2019/11/13.
//  Copyright © 2019 luowailin. All rights reserved.
//

#include "BlockingQueue.hpp"

BlockingQueue::BlockingQueue(){
    pthread_mutex_init(&mLock, nullptr);
    pthread_cond_init(&mCondition, nullptr);
}

BlockingQueue::~BlockingQueue(){
    flush();
    pthread_mutex_destroy(&mLock);
    pthread_cond_destroy(&mCondition);
}

int BlockingQueue::put(AudioPacket *audioPacket){
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
    pthread_mutex_lock(&mLock);
    if (mLast == nullptr) {
        mFirst = pkt1;
    } else{
        mLast->next = pkt1;
    }
    mLast = pkt1;
    mNbPackets ++;
    
    pthread_cond_signal(&mCondition);
    pthread_mutex_unlock(&mLock);
    return 0;
}

int BlockingQueue::get(AudioPacket **audioPacket, bool block){
    AudioPacketList *pkt1;
    int ret = 0;
    pthread_mutex_lock(&mLock);
    while (1) {
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
            
            mNbPackets --;
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

void BlockingQueue::flush(){
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

void BlockingQueue::abort(){
    pthread_mutex_lock(&mLock);
    mAbortRequest = true;
    pthread_cond_signal(&mCondition);
    pthread_mutex_unlock(&mLock);
}
