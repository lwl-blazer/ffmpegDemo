//
//  BLImageCameraRenderer.h
//  BLVideoToolboxEncoder
//
//  Created by luowailin on 2019/10/29.
//  Copyright © 2019 luowailin. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "BLImageContext.h"

NS_ASSUME_NONNULL_BEGIN

@interface BLImageCameraRenderer : NSObject

- (BOOL)prepareRender:(BOOL)isFullYUVRange;

- (void)renderWithSampleBuffer:(CMSampleBufferRef)sampleBuffer
                   aspectRatio:(float)aspectRatio
           preferredConversion:(const GLfloat *)preferredConversion
                 imageRotation:(BLImageRotationMode)inputTexRotation;

@end

NS_ASSUME_NONNULL_END
