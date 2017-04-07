//
//  RotateBuffer.h
//  FaceCar
//
//  Created by Hao Lee on 2017/4/7.
//  Copyright © 2017年 Speed3D Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreMedia/CoreMedia.h>

@interface RotateBuffer : NSObject

- (CMSampleBufferRef)rotateBuffer:(CMSampleBufferRef)sampleBuffer withConstant:(uint8_t)rotationConstant;

@end
