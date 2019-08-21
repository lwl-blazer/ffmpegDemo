//
//  packet_pool.cpp
//  AudioPlayer
//
//  Created by luowailin on 2019/8/5.
//  Copyright © 2019 luowailin. All rights reserved.
//

#include "packet_pool.hpp"
#define LOG_TAG "SongStudio PacketPool"

PacketPool::PacketPool(){
    
}

PacketPool::~PacketPool(){
    
}

PacketPool* PacketPool::instance = new PacketPool();
PacketPool* PacketPool::GetInstance(){
    return instance;
}

/** decoder original song packet queue process **/
void PacketPool::initDecoderOriginalSongPacketQueue(){
    const char *name = "decoder original song packet queue";
    decoderOriginalSongPacketQueue = new PacketQueue(name);
}

void PacketPool::abortDecoderOriginalSongPacketQueue(){
    if (nullptr != decoderOriginalSongPacketQueue) {
        decoderOriginalSongPacketQueue->abort();
    }
}

void PacketPool::destoryDecoderOringalSongPacketQueue(){
    if (nullptr != decoderOriginalSongPacketQueue) {
        delete decoderOriginalSongPacketQueue;
        decoderOriginalSongPacketQueue = nullptr;
    }
}

int PacketPool::getDecoderOriginalSongPacket(AudioPacket **audioPacket, bool block){
    int result = -1;
    if (nullptr != decoderOriginalSongPacketQueue) {
        result = decoderOriginalSongPacketQueue->get(audioPacket, block);
    }
    return result;
}

int PacketPool::getDecoderOriginalSongPacketQueueSize(){
    return decoderOriginalSongPacketQueue->size();
}

void PacketPool::pushDecoderOriginalSongPacketToQueue(AudioPacket *audioPacket){
    decoderOriginalSongPacketQueue->put(audioPacket);
}

void PacketPool::clearDecoderOriginalSongPacketQueue(){
    decoderOriginalSongPacketQueue->flush();
}


/*** decoder accompany packet queue process **/
void PacketPool::initDecoderAccompanyPacketQueue(){
    const char *name = "decoder accompany packet queue";
    decoderAccompanyPacketQueue = new PacketQueue(name);
}

void PacketPool::abortDecoderAccompanyPacketQueue(){
    if (nullptr != decoderAccompanyPacketQueue) {
        decoderAccompanyPacketQueue->abort();
    }
}

void PacketPool::destoryDecoderAccompanyPacketQueue(){
    if (nullptr != decoderAccompanyPacketQueue) {
        delete decoderAccompanyPacketQueue;
        decoderAccompanyPacketQueue = nullptr;
    }
}

int PacketPool::getDecoderAccompanyPacket(AudioPacket **audioPacket, bool block){
    int result = -1;
    if (nullptr != decoderAccompanyPacketQueue) {
        result = decoderAccompanyPacketQueue->get(audioPacket, block);
    }
    return result;
}

int PacketPool::getDecoderAccompanyPacketQueueSize(){
    return decoderAccompanyPacketQueue->size();
}

void PacketPool::clearDecoderAccompanyPacketToQueue(){
    decoderAccompanyPacketQueue->flush();
}

void PacketPool::pushDecoderAccompanyPacketToQueue(AudioPacket *audioPacket){
    decoderAccompanyPacketQueue->put(audioPacket);
}


/*** audio packet queue process **/
void PacketPool::initAudioPacketQueue(){
    const char *name = "audioPacket queue";
    audioPacketQueue = new PacketQueue(name);
}

void PacketPool::abortAudioPacketQueue(){
    if (nullptr != audioPacketQueue) {
        audioPacketQueue->abort();
    }
}

void PacketPool::destoryAudioPacketQueue(){
    if (nullptr != audioPacketQueue) {
        delete audioPacketQueue;
        audioPacketQueue = nullptr;
    }
}

int PacketPool::getAudioPacket(AudioPacket **audioPacket, bool block){
    int result = -1;
    if (nullptr != audioPacketQueue) {
        result = audioPacketQueue->get(audioPacket, block);
    }
    return result;
}

int PacketPool::getAudioPacketQueueSize(){
    return audioPacketQueue->size();
}

void PacketPool::pushAudioPacketToQueue(AudioPacket *audioPacket){
    audioPacketQueue->put(audioPacket);
}

void PacketPool::clearAudioPacketToQueue(){
    audioPacketQueue->flush();
}

/*** accompany packet queue process **/
void PacketPool::initAccompanyPacketQueue(){
    const char *name = "accompany queue";
    accompanyPacketQueue = new PacketQueue(name);
}

void PacketPool::abortAccompanyPacketQueue(){
    if (accompanyPacketQueue != nullptr) {
        accompanyPacketQueue->abort();
    }
}

void PacketPool::destoryAccompanyPacketQueue(){
    if (nullptr != accompanyPacketQueue) {
        delete accompanyPacketQueue;
        accompanyPacketQueue = nullptr;
    }
}

int PacketPool::getAccompanyPacket(AudioPacket **accompanyPacket, bool block){
    int result = -1;
    if (nullptr != accompanyPacketQueue) {
        result = accompanyPacketQueue->get(accompanyPacket, block);
    }
    return result;
}

int PacketPool::getAccompanyPacketQueueSize(){
    return accompanyPacketQueue->size();
}

void PacketPool::pushAccompanyPacketToQueue(AudioPacket *accompanyPacket){
    accompanyPacketQueue->put(accompanyPacket);
}

void PacketPool::clearAccompanyPacketQueue(){
    if (accompanyPacketQueue != nullptr) {
        accompanyPacketQueue->flush();
    }
}


/*** live packet queue process **/
void PacketPool::initLivePacketQueue(){
    const char *name = "livePacket queue";
    livePacketQueue = new PacketQueue(name);
}

void PacketPool::abortLivePacketQueue(){
    if (nullptr != livePacketQueue) {
        livePacketQueue->abort();
    }
}

void PacketPool::destoryLivePacketQueue(){
    if (nullptr != livePacketQueue) {
        delete livePacketQueue;
        livePacketQueue = nullptr;
    }
}

int PacketPool::getLivePacket(AudioPacket **livePacket, bool block){
    int result = -1;
    if (nullptr != livePacketQueue) {
        result = livePacketQueue->get(livePacket, block);
    }
    return result;
}

int PacketPool::getLivePacketQueueSize(){
    int result = -1;
    if (nullptr != livePacketQueue) {
        result = livePacketQueue->size();
    }
    return result;
}

void PacketPool::pushLivePacketToQueue(AudioPacket *livePacket){
    livePacketQueue->put(livePacket);
}


/*** liveSubscriber packet queue process **/
void PacketPool::initLiveSubscriberPacketQueue(){
    const char *name = "liveSubscriberPacket Queue";
    liveSubscriberPacketQueue = new PacketQueue(name);
}

void PacketPool::abortLiveSubscriberPacketQueue(){
    if (nullptr != liveSubscriberPacketQueue) {
        liveSubscriberPacketQueue->abort();
    }
}

void PacketPool::destoryLiveSubscriberPacketQueue(){
    if (nullptr != liveSubscriberPacketQueue) {
        delete liveSubscriberPacketQueue;
        liveSubscriberPacketQueue = nullptr;
    }
}

int PacketPool::getLiveSubscriberPacket(AudioPacket **livePacket, bool block){
    int result = -1;
    if (nullptr != liveSubscriberPacketQueue) {
        result = liveSubscriberPacketQueue->get(livePacket, block);
    }
    return result;
}

int PacketPool::getLiveSubscriberPacketQueueSize(){
    return liveSubscriberPacketQueue->size();
}

void PacketPool::pushLiveSubscriberPacketToQueue(AudioPacket *livePacket){
    liveSubscriberPacketQueue->put(livePacket);
}


/*** Tuning packet queue process **/
void PacketPool::initTuningPacketQueue(){
    const char *name = "tuningPacket queue";
    tuningPacketQueue = new PacketQueue(name);
}

void PacketPool::abortTuningPacketQueue(){
    if (nullptr != tuningPacketQueue) {
        tuningPacketQueue->abort();
    }
}

void PacketPool::destoryTuningPacketQueue(){
    if (nullptr != tuningPacketQueue) {
        delete tuningPacketQueue;
        tuningPacketQueue = nullptr;
    }
}

int PacketPool::getTuningPacket(AudioPacket **tuningPacket, bool block){
    int result = -1;
    if (nullptr != tuningPacketQueue) {
        result = tuningPacketQueue->get(tuningPacket, block);
    }
    return result;
}

int PacketPool::getTuningPacketQueueSize(){
    return tuningPacketQueue->size();
}

void PacketPool::pushTuningPacketToQueue(AudioPacket *tuningPacket){
    tuningPacketQueue->put(tuningPacket);
}
