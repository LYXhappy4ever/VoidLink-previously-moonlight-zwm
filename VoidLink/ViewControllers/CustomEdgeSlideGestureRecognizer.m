//
//  CustomEdgeSlideGestureRecognizer.m
//  VoidLink
//
//  Created by True砖家 on 2024/4/30.
//  Copyright © 2024 True砖家 on Bilibili. All rights reserved.
//

// #import <Foundation/Foundation.h>

#import "CustomEdgeSlideGestureRecognizer.h"
#import <UIKit/UIGestureRecognizerSubclass.h>
#import "VoidLink-Swift.h"

@implementation CustomEdgeSlideGestureRecognizer {
    UITouch* _capturedUITouch;
    CGFloat _startPointX;
}

- (instancetype)initWithTarget:(nullable id)target action:(nullable SEL)action {
    self = [super initWithTarget:target action:action];
    _immediateTriggering = false;
    _edgeTolerance = 10.0f;
    return self;
}

- (void)reset {
    [super reset];
    _capturedUITouch = nil;
    _startPointX = 0;
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    if (touches.count > 1 || _capturedUITouch != nil) {
        self.state = UIGestureRecognizerStateFailed;
        return;
    }
    UITouch *touch = [touches anyObject];
    if (_excludePencilEvent && touch.type != UITouchTypeDirect) {
        self.state = UIGestureRecognizerStateFailed;
        return;
    }
    // Never intercept touches targeting on-screen widgets, floating keyboard button, quick action panel, or voice draft overlay.
    for (UIView *v = touch.view; v != nil; v = v.superview) {
        if ([v isKindOfClass:[OnScreenWidgetView class]] ||
            [v isKindOfClass:[FloatingKeyboardButton class]] ||
            [v isKindOfClass:[QuickActionPanelView class]] ||
            [v isKindOfClass:[VoiceTextDraftOverlayView class]]) {
            self.state = UIGestureRecognizerStateFailed;
            return;
        }
    }
    CGFloat startX = [touch locationInView:self.view].x;
    CGFloat viewWidth = self.view.bounds.size.width;
    BOOL inLeftEdge = (self.edges & UIRectEdgeLeft) && (startX < _edgeTolerance);
    BOOL inRightEdge = (self.edges & UIRectEdgeRight) && (startX > viewWidth - _edgeTolerance);
    if (!inLeftEdge && !inRightEdge) {
        self.state = UIGestureRecognizerStateFailed;
        return;
    }

    _capturedUITouch = touch;
    _startPointX = startX;
    if (_immediateTriggering) {
        self.state = UIGestureRecognizerStateEnded;
    } else {
        self.state = UIGestureRecognizerStatePossible;
    }
}

- (void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    if (_capturedUITouch == nil || ![touches containsObject:_capturedUITouch]) return;
    if (OnScreenWidgetView.deferSlideGestureDueToAutoDockRestore) {
        self.state = UIGestureRecognizerStateFailed;
        return;
    }
    CGFloat currentX = [_capturedUITouch locationInView:self.view].x;
    CGFloat viewWidth = self.view.bounds.size.width;
    if (viewWidth <= 0) return;
    CGFloat normalizedDistance = fabs(currentX - _startPointX) / viewWidth;
    BOOL validDirection = ((self.edges & UIRectEdgeLeft) && currentX > _startPointX) ||
                          ((self.edges & UIRectEdgeRight) && currentX < _startPointX);
    if (validDirection && normalizedDistance > _normalizedThresholdDistance) {
        self.state = UIGestureRecognizerStateEnded;
    }
}

- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    if (_excludePencilEvent && touches.anyObject.type != UITouchTypeDirect) {
        self.state = UIGestureRecognizerStateFailed;
        return;
    }
    if (OnScreenWidgetView.deferSlideGestureDueToAutoDockRestore) {
        self.state = UIGestureRecognizerStateFailed;
        return;
    }
    if (_capturedUITouch != nil && [touches containsObject:_capturedUITouch]) {
        CGFloat endX = [_capturedUITouch locationInView:self.view].x;
        CGFloat viewWidth = self.view.bounds.size.width;
        CGFloat normalizedDistance = viewWidth > 0 ? fabs(endX - _startPointX) / viewWidth : 0;
        BOOL inEdge = ((self.edges & UIRectEdgeLeft) && _startPointX < _edgeTolerance) ||
                      ((self.edges & UIRectEdgeRight) && _startPointX > (viewWidth - _edgeTolerance));
        if (inEdge && normalizedDistance > _normalizedThresholdDistance) {
            self.state = UIGestureRecognizerStateEnded;
        } else {
            self.state = UIGestureRecognizerStateFailed;
        }
    } else {
        self.state = UIGestureRecognizerStateFailed;
    }
}

- (void)touchesCancelled:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    self.state = UIGestureRecognizerStateFailed;
}

@end





