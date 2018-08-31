//
//  xukangwenViewController.m
//  H264ToFlv
//
//  Created by zhengyu xu on 14-2-26.
//  Copyright (c) 2014年 smg. All rights reserved.
//

#import "xukangwenViewController.h"

@interface xukangwenViewController ()

@end

@implementation xukangwenViewController
@synthesize VideoListArray;

int first1=0;
int topTagLen=16;
int metaFixLen=27;
int first2=0;
int videoLen=0;
int videoTagFixLen=20;


void get2Byte(char (*array)[2] , NSInteger size){
    (*array)[0] = (size & 0x0000FF00) >> 8;
    (*array)[1] = (size & 0x000000FF) >> 0;
}

void get3Byte(char (*array)[3] , NSInteger size){
    (*array)[0] = (size & 0x00FF0000) >> 16;
    (*array)[1] = (size & 0x0000FF00) >> 8;
    (*array)[2] = (size & 0x000000FF) >> 0;
}

void get4Byte(char (*array)[4] , NSInteger size){
    (*array)[0] = (size & 0x00FF0000) >> 24;
    (*array)[1] = (size & 0x00FF0000) >> 16;
    (*array)[2] = (size & 0x0000FF00) >> 8;
    (*array)[3] = (size & 0x000000FF) >> 0;
}

- (void)viewDidLoad
{
    [super viewDidLoad];    if(NULL==self.VideoListArray){
        self.VideoListArray=[[NSMutableArray alloc] init];
        
    }else{
        if([self.VideoListArray count]>0){
            [self.VideoListArray removeAllObjects];
        }
    }
    [self TestBitFile];
}

-(void)initH264File:(NSString *)path{

    NSInteger size = 0;
    
    NSData * reader = [NSData dataWithContentsOfFile:path];//H264裸数据
    
    [reader getBytes:&size length:sizeof(size)];
    
    Byte *contentByte = (Byte *)[reader bytes];
    
    int count_i=-1;
    
       Byte kk;
    for(int i=0;i<[reader length];i++){
        
        if((i+3)>=[reader length]){
            break;
        }
        if(contentByte[i+0]==0x00&&contentByte[i+1]==0x00&&contentByte[i+2]==0x00&&contentByte[i+3]==0x01){
            
            i=i+3;
            
            count_i++;
            
            [self.VideoListArray addObject:[[NSMutableData alloc] init]];
        }else{
            
            if(count_i>-1){
                 kk=contentByte[i];
                [[self.VideoListArray objectAtIndex:count_i] appendBytes:&kk length:sizeof(kk)];
            }
        }
    }
}

-(void)TestBitFile{
    NSString *documentPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
	NSString *realPath = [documentPath stringByAppendingPathComponent:@"IOSencoder.flv"];
    NSString *realPath2 = [documentPath stringByAppendingPathComponent:@"encoder.h264"];
    NSFileManager *fileManager=[NSFileManager defaultManager];
    
    if (![fileManager fileExistsAtPath:realPath]){
        [self initH264File:realPath2];
        NSMutableData *writer = [[NSMutableData alloc] init];
        
    /** FLV header*/
        char flvHader[] = {0x46, 0x4C, 0x56, 0x01, 0x01, 0x00, 0x00, 0x00,0x09};
        [writer appendBytes:&flvHader length:sizeof(flvHader)];//1
        
        /** lastTagSize */
        char lastTagSize [4] = {};
        get4Byte(&lastTagSize, 0);
        [writer appendBytes:&lastTagSize length:sizeof(lastTagSize)];//1
        
    /** videoTagHeader */
        /** tag类型 */
        Byte i1 = 0x09;
        [writer appendBytes:&i1 length:sizeof(i1)];//14
        
        /**  tagData长度 */
        NSUInteger size = topTagLen + [[self.VideoListArray objectAtIndex:0] length] + [[self.VideoListArray objectAtIndex:1] length];
        char tagDataSize [3] = {};
        get3Byte(&tagDataSize, size);
        [writer appendBytes:&tagDataSize length:sizeof(tagDataSize)];

        /** 时间戳 */
        char timeStamp [] = {0x00, 0x00, 0x00, 0x00};
        [writer appendBytes:&timeStamp length:sizeof(timeStamp)];
        
        /** 流 id */
        char streamId[] = {0x00, 0x00, 0x00};
        [writer appendBytes:&streamId length:sizeof(streamId)];

    /** tagBody */
        /**
         0000190: 0900 0033 0000 0000 0000 0017 0000 0000  ...3............
         00001a0: 0164 002a ffe1 001e 6764 002a acd9 4078  .d.*....gd.*..@x
         00001b0: 0227 e5ff c389 4388 0400 0003 0028 0000  .'....C......(..
         00001c0: 0978 3c60 c658 0100 0568 ebec b22c 0000  .x<`.X...h...,..

         17:表示h264IDR data
         00：表示是AVC序列头
         00 00 00 ：cts为0
         01 ：版本号
         64 00 2a：profile level id，sps的三个字节，64表示是h264 high profile，2a表示level。
         FF：NALU长度，
         E1：表示下面紧跟SPS有一个。
         00 1e:    前面是两个字节的sps长度，表示后面的sps的长度是1e大小。
         6764 002a acd9 4078 0227 e5ff c389 4388 0400 0003 0028 0000 0978 3c60 c658：sps的数据。
         01 ：pps个数，1
         00 05：表示pps的大小是5个字节。
         68 eb ec b2 2c：pps的数据
         00 00 …….这是下一个tag 的内容了
         */
        char avcHeader[] = {0x17, 0x00, 0x00, 0x00, 0x00, 0x01, 0x42, 0x80, 0x0D, 0xFF, 0xE1};
        [writer appendBytes:&avcHeader length:sizeof(avcHeader)];//18
        
        /** sps 长度 */
        char spsSize [2] = {};
        get2Byte(&spsSize, [[self.VideoListArray objectAtIndex:0] length]);
        [writer appendBytes:&spsSize length:sizeof(spsSize)];//17
        
         /** sps 数据 */
        [writer appendData:[self.VideoListArray objectAtIndex:0]];
        
        /** pps 个数和 pps 长度 */
        i1 = 0x01;
        [writer appendBytes:&i1 length:sizeof(i1)];//14

        char ppsSize [2] = {};
        get2Byte(&ppsSize, [[self.VideoListArray objectAtIndex:1] length]);
        [writer appendBytes:&ppsSize length:sizeof(ppsSize)];//18

        /** pps 数据 */
        [writer appendData:[self.VideoListArray objectAtIndex:1]];

        
        int time_h = 0;
        for(int j=2;j<[self.VideoListArray count];j++){
            
            /** lastTagSize */
            size = (j==2) ?
            metaFixLen+[[self.VideoListArray objectAtIndex:0] length]+[[self.VideoListArray objectAtIndex:1] length] :
            videoTagFixLen+[[self.VideoListArray objectAtIndex:j-1] length];
            char lastTagSize[4] = {};
            get4Byte(&lastTagSize, size);
            [writer appendBytes:&lastTagSize length:sizeof(lastTagSize)];

        /** tagHeader 类型 */
            /** 类型 */
            i1 = 0x09;
            [writer appendBytes:&i1 length:sizeof(i1)];
            
            size = [[self.VideoListArray objectAtIndex:j] length] + 9;
            char tagDataSize [3] = {};
            get3Byte(&tagDataSize, size);
            [writer appendBytes:&tagDataSize length:sizeof(tagDataSize)];//18
            
            /** 时间戳 */
            char timeStamp [3] = {};
            get3Byte(&timeStamp, time_h);
            [writer appendBytes:&timeStamp length:sizeof(timeStamp)];//18
            
            /** 备用时间戳 */
            i1 = 0x00;
            [writer appendBytes:&i1 length:sizeof(i1)];//18
            
            /** 流 id */
            char streamId[] = {0x00, 0x00, 0x00};
            [writer appendBytes:&streamId length:sizeof(streamId)];//18
            
        /** avcHeader */
            Byte *contentByte = (Byte *)[[self.VideoListArray objectAtIndex:j] bytes];
            i1 = ((contentByte[0] & 0x1f) == 5) ? 0x17 : 0x27;
            char avcHeader[] = {i1, 0x01, 0x00, 0x00, 0x00};
            [writer appendBytes:&avcHeader length:sizeof(avcHeader)];
            
            /** nalu 长度 */
            size=[[self.VideoListArray objectAtIndex:j] length];
            char tagSize[4] = {};
            get4Byte(&tagSize, size);
            [writer appendBytes:&tagSize length:sizeof(tagSize)];
            
            /** nalu 数据*/
           [writer appendData:[self.VideoListArray objectAtIndex:j]];

            time_h = time_h + 40;
        }
        [writer writeToFile:realPath atomically:YES];
    }
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
