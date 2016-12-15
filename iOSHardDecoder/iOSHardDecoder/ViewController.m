//
//  ViewController.m
//  iOSHardDecoder
//
//  Created by EthanLuo on 16/12/15.
//  Copyright © 2016年 Ethan.Luo. All rights reserved.
//

#import "ViewController.h"
#import "ETMediaClient.h"
#define NEWBUFFER_SIZE  30*1024*1024/20  //==1.5M
@interface ViewController ()
@property (nonatomic, strong) ETMediaClient *mediaClient0;
@property (nonatomic, strong) ETMediaClient *mediaClient1;
@property (nonatomic, strong) UIView *videoView;

@property (nonatomic, assign) BOOL startPlay;
@property (nonatomic, strong) NSThread *sendFrameThread;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.automaticallyAdjustsScrollViewInsets = YES;
    
    self.videoView.backgroundColor = [UIColor grayColor];
    
    //1.使用mediaClient 自带View
    self.mediaClient0 = [[ETMediaClient alloc] initWithFrame:CGRectMake(0, 0, self.view.frame.size.width, self.view.frame.size.height/3)];
    [self.view addSubview:self.mediaClient0.videoView];
    
    //2.使用外部Video View
    self.videoView = [[UIView alloc] initWithFrame:CGRectMake(0, self.view.frame.size.height/2, self.view.frame.size.width, self.view.frame.size.height/3)];
    self.mediaClient1 = [[ETMediaClient alloc] initWithSuperView:self.videoView];
    [self.view addSubview:self.videoView];
    
    UIButton *button = [[UIButton alloc] initWithFrame:CGRectMake(0, self.view.frame.size.height-60, 80, 50)];
    
    button.backgroundColor = [UIColor greenColor];
    
    [button setTitle:@"开始" forState:UIControlStateNormal];
    
    [button setTitleColor:[UIColor redColor] forState:UIControlStateNormal];
    
    [button addTarget:self action:@selector(buttonAction:) forControlEvents:UIControlEventTouchUpInside];
    
    [self.view insertSubview:button atIndex:0];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(orientChange:) name:UIDeviceOrientationDidChangeNotification object:nil];
}

- (void)buttonAction:(UIButton *)sender {
    if (YES == self.startPlay) {
        [self.sendFrameThread cancel];
        [self.mediaClient0 stopDecodeing];
        [self.mediaClient1 stopDecodeing];
        self.startPlay = NO;
        
        [sender setTitle:@"开始" forState:UIControlStateNormal];
    }
    else {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [self.mediaClient0 startDecodeing];
            [self.mediaClient1 startDecodeing];
            self.startPlay = YES;
            self.sendFrameThread = [[NSThread alloc] initWithTarget:self selector:@selector(startSendVideoData) object:nil];
            [self.sendFrameThread start];
        });
        [sender setTitle:@"结束" forState:UIControlStateNormal];
    }
}

- (void)orientChange:(NSNotification *)noti
{
    UIDeviceOrientation  orient = [UIDevice currentDevice].orientation;
    switch (orient)
    {
            
        case UIDeviceOrientationPortrait:
            [self dealVideoViewRotate];
            break;
            
        case UIDeviceOrientationLandscapeLeft:
            [self dealVideoViewRotate];
            break;
            
        case UIDeviceOrientationPortraitUpsideDown:
            break;
            
        case UIDeviceOrientationLandscapeRight:
            [self dealVideoViewRotate];
            break;
            
        default:
            
            break;
    }
}

- (void) dealVideoViewRotate {
    [UIView animateWithDuration:0.3 animations:^{
        if (self.view.frame.size.height < self.view.frame.size.width) {
            [self.mediaClient0 updateVideoFrame:CGRectMake(0, 0, self.view.frame.size.width/2, self.view.frame.size.height)];
            
            self.videoView.frame = CGRectMake(self.view.frame.size.width/2, 0, self.view.frame.size.width/2, self.view.frame.size.height);
            [self.mediaClient1 updateVideoFrame:self.videoView.frame];
        }
        else {
            [self.mediaClient0 updateVideoFrame:CGRectMake(0, 0, self.view.frame.size.width, self.view.frame.size.height/3)];
            
            self.videoView.frame = CGRectMake(0, self.view.frame.size.height/2, self.view.frame.size.width, self.view.frame.size.height/3);
            [self.mediaClient1 updateVideoFrame:self.videoView.frame];
        }
    }];
}

- (void) startSendVideoData {
    NSString *path = [[NSBundle mainBundle] pathForResource:@"VGA"ofType:@"h264"];
    NSLog(@"path = %@", path);
    
    char * filePath = (char *)[path cStringUsingEncoding:NSUTF8StringEncoding];
    FILE *fp = fopen(filePath, "rb");
    if(!fp)
    {
        NSLog(@"ERROR:open file failed!\n");
        return;
    }
    fseek(fp, 0, SEEK_SET);
    
    long readlen = 0;
    unsigned char *buffer;
    buffer = malloc(NEWBUFFER_SIZE);
    
    if (!buffer) {
        NSLog(@"ERROR:malloc buffer failed!\n");
        return;
    }
    
    /**
     NEWBUFFER_SIZE的大小要跟文件大小一样大，后面的分析代码暂时没做buffer拼接，否则可能会把完整帧分包，导致分析失败.
     或者上层保证每次读取的buffer都是完整帧的数据。
     此处也可以用 NSInputStream 来读入数据，更简单
     */
    
    while(TRUE && ![[NSThread currentThread] isCancelled])
    {
        memset(buffer, 0, NEWBUFFER_SIZE);
        readlen = fread(buffer, sizeof(unsigned char), (long)NEWBUFFER_SIZE, fp);
        if(readlen<=0)
        {
            printf("ERROR:Read  video  failed!----\n");
            
            self.mediaClient0.endData = YES;
            self.mediaClient1.endData = YES;
            break;
        }
        [self.mediaClient0 sendFrameDataToDecodeQueue:buffer length:readlen];
        [self.mediaClient1 sendFrameDataToDecodeQueue:buffer length:readlen];
        
        //此处发送数据做帧控制
//        usleep(1000*1000/60);
    }
    
    free(buffer);
    fclose(fp);
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
    
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIDeviceOrientationDidChangeNotification object:nil];
}

@end
