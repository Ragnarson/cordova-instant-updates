//
//  CodeUpdater.h
//  HelloCordova
//
//  Created by Pawel Urbanek on 06/12/15.
//
//

#import <Foundation/Foundation.h>
#import "MainViewController.h"

@interface CodeUpdater : NSObject

- (instancetype)initWithViewController:(CDVViewController *)viewController;
- (void) call;

@end
