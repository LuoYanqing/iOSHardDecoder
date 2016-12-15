//
//  ETDecoderHeader.h
//  netsdk
//
//  Created by EthanLuo on 16/12/13.
//  Copyright © 2016年 EricTao. All rights reserved.
//

#ifndef ETDecoderHeader_h
#define ETDecoderHeader_h
#ifdef DEBUG
#define ETLog(FORMAT, ...){\
NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];\
[dateFormatter setDateStyle:NSDateFormatterMediumStyle];\
[dateFormatter setTimeStyle:NSDateFormatterShortStyle];\
[dateFormatter setDateFormat:@"yyyy-MM-dd HH:mm:ss:SSS"]; \
NSString *str = [dateFormatter stringFromDate:[NSDate date]];\
\
fprintf(stderr,"Ethan.Luo [--%s--]func:%s,line:%d\t%s\n",[str UTF8String],[[[NSString stringWithUTF8String:__func__] lastPathComponent] UTF8String], __LINE__, [[NSString stringWithFormat:FORMAT, ##__VA_ARGS__] UTF8String]);\
}
#else
#define ETLog(FORMAT, ...) while(0){}
#endif

#endif /* ETDecoderHeader_h */
