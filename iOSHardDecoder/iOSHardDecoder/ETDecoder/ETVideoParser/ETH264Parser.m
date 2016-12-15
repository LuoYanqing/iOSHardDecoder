//
//  ETH264Parser.m
//  iOSHardwareDecoder
//
//  Created by EthanLuo on 16/12/10.
//  Copyright © 2016年 Ethan.Luo. All rights reserved.
//

#import "ETH264Parser.h"
#include <string.h>

const uint8_t KStartCode[4] = {0, 0, 0, 1};
const uint8_t kkStartCode[7] = {0, 0, 0, 1, 103, 66, 0};

@interface ETH264Parser ()
@end
@implementation ETH264Parser


+ (NSMutableArray *)packetVideoData:(uint8_t *)videoBuffer bufferLength:(NSInteger)bufferLength {
    NSMutableArray *videoPacketArray = [NSMutableArray array];
    //该方法只封装打包完整帧的数据段，可以有多个完整帧，但是帧数据不能分包传递，分包传输的数据此种方法不适合
    uint8_t *tmpBuffer;
    tmpBuffer = videoBuffer;//malloc(_bufferCap);
    
//    memcpy(_buffer, buffer, bufferLength);
    if(memcmp(tmpBuffer, KStartCode, 4) != 0) {
        ETLog(@"此数据段没有头，丢弃该数据， bufferLength = %ld", (long)bufferLength);
//        free(_buffer);
        return nil;
    }
    
    //将数据段打包处理
    uint8_t *bufferBegin = tmpBuffer + 4;//将读取的空间先右移4个字节，即，跳过第一个startCode,取为读取开始指针
    uint8_t *bufferEnd = tmpBuffer + bufferLength;//取到buffer尾部的指针
    
    while(bufferBegin != bufferEnd) {
        NSInteger packetSize = 0;
        
        if(*bufferBegin == 0x01)
        {
            //找到第二个startCode
            if(memcmp(bufferBegin - 3, KStartCode, 4) == 0){
                //计算出两个starCode之间的数据长度，并从Buffer中剔除后面一个starCode
                packetSize = (bufferBegin - 3) - tmpBuffer;
                
                ETVideoPacket *videoPacket = [[ETVideoPacket alloc] initWithSize:packetSize];
                //拷贝数据长度
//                memcpy(videoPacket.buffer, tmpBuffer, packetSize);
                videoPacket.bufferData = [NSData dataWithBytes:tmpBuffer length:packetSize];

                [videoPacketArray addObject:videoPacket];

                tmpBuffer = tmpBuffer + packetSize;

                if (4 < bufferEnd-tmpBuffer) {
                    bufferBegin = tmpBuffer + 4;
                    continue;
                }
                else {
                    break;
                }
            }
        }
        
        bufferBegin++;
        
        if (bufferBegin == bufferEnd && tmpBuffer != bufferEnd) {
            //计算出两个starCode之间的数据长度，并从Buffer中剔除后面一个starCode
            NSInteger packetSize = bufferBegin - tmpBuffer;
            
            ETVideoPacket *videoPacket = [[ETVideoPacket alloc] initWithSize:packetSize];
            //拷贝数据长度
//            memcpy(videoPacket.buffer, tmpBuffer, packetSize);
            videoPacket.bufferData = [NSData dataWithBytes:tmpBuffer length:packetSize];
            
            [videoPacketArray addObject:videoPacket];
            
            break;
        }
    }
    
//    free(_buffer);
    return videoPacketArray;
}




+ (ETVideoPacket *)parseVideoPacket:(ETVideoPacket *)srcPacket {

    return nil;
}

#pragma mark -- 解析网络视频数据头信息，针对H264格式
+ (bool)praseMetadataWithData:(const unsigned char*)pData withLength:(long)size withMetadata:(ETMp4EncMetadata *)metadata
{
    if(pData == NULL || size<4)
    {
        return false;
    }
    
    //MP4ENC_NaluUnit nalu;
    ETMp4EncNaluUnit nalu = {0};
    
    int pos = 0;
    long len = 0;
    bool bRet1 = false,bRet2 = false;
    //while (long len = ReadOneNaluFromBuf(pData,size,pos,nalu))
//    unsigned char* ppdata = pData + 4;

    while ((len = [ETH264Parser readOneNaluWithData:pData withLength:size withOffset:pos withNaluInfo:&nalu]))
    {
        if(nalu.type == 0x07)
        {
//            ETLog(@"get SPS FRAME");
            memcpy(metadata->Sps,nalu.data,nalu.size);
            metadata->nSpsLen = nalu.size;
            bRet1 = true;
        }
        else if(nalu.type == 0x08)
        {
//            ETLog(@"get pps FRAME");
            memcpy(metadata->Pps,nalu.data,nalu.size);
            metadata->nPpsLen = nalu.size;
            bRet2 = true;
        }
        pos += len;
        
        if(bRet1 && bRet2)
        {
            break;
        }
    }
    
    if(bRet1 && bRet2)
    {
        return true;
    }
    
    return false;
}

+ (long)readOneNaluWithData:(const unsigned char*)pData withLength:(long)length withOffset:(long)offset withNaluInfo:(ETMp4EncNaluUnit *)nalu
{
    long i = offset;
    long pos = 0;

    while(i<length)
    {
        if(pData[i++] == 0x00 &&
           pData[i++] == 0x00 &&
           pData[i++] == 0x00 &&
           pData[i++] == 0x01
           )
        {
            pos = i;
            while (pos<length)
            {
                if(pData[pos++] == 0x00 &&
                   pData[pos++] == 0x00 &&
                   pData[pos++] == 0x00 &&
                   pData[pos++] == 0x01
                   )
                {
                    break;
                }
            }
            
            if(pos == length)
            {
                nalu->size = pos-i;
            }
            else
            {
                nalu->size = (pos-4)-i;
            }
            
            nalu->type = pData[i]&0x1f;
            nalu->data =(unsigned char*)&pData[i];
            return (nalu->size + i - offset);
        }
    }
    return 0;
}
@end
