//
//  JPSImagePickerController.m
//  JPSImagePickerController
//
//  Created by JP Simard on 1/31/2014.
//  Copyright (c) 2014 JP Simard. All rights reserved.
//

#import "JPSImagePickerController.h"
#import "JPSCameraButton.h"
#import "JPSImageMask.h"
#import "UIImage+Rotation.h"

@interface JPSImagePickerController () <UIScrollViewDelegate>

// Camera - "capture" means the live preview
@property (nonatomic, strong) AVCaptureSession           * session;
@property (nonatomic, strong) UIView                     * capturePreviewView;
@property (nonatomic, strong) AVCaptureVideoPreviewLayer * capturePreviewLayer;
@property (nonatomic, strong) NSOperationQueue           * captureQueue;
@property (nonatomic, assign) UIImageOrientation           imageOrientation;
@property (nonatomic, assign) AVCaptureDevicePosition      cameraPosition;
@property (nonatomic, assign) UIInterfaceOrientation       initialInterfaceOrientation;
@property (nonatomic, assign) UIDeviceOrientation          previewDeviceOrientation;
@property (nonatomic, assign) UIImageOrientation           previewImageOrientation;

// Camera Controls
@property (nonatomic, strong) UIButton *cameraButton;
@property (nonatomic, strong) UIButton *cancelButton;
@property (nonatomic, strong) UIButton *flashButton;
@property (nonatomic, strong) UIButton *cameraSwitchButton;

// Preview - meaning the preview of the snapped photo
@property (nonatomic, strong) UIImage     * previewImage;
@property (nonatomic, strong) UIScrollView     * previewScrollView;
@property (nonatomic, strong) UIImageView * previewImageView;
@property (nonatomic, strong) UIButton    * retakeButton;
@property (nonatomic, strong) UIButton    * useButton;

// Preview Top Area
@property (nonatomic, strong) UILabel * confirmationLabel;
@property (nonatomic, strong) UILabel * confirmationOverlayLabel;
@property (nonatomic, strong) JPSImageMask *previewImageMask;

@property (nonatomic, weak) id<JPSImagePickerDelegate> delegate;

@end

@implementation JPSImagePickerController

+(NSBundle *)bundle
{
    static NSBundle *bundle;
    static dispatch_once_t once;
    dispatch_once(&once, ^
    {
        bundle = [NSBundle bundleWithPath:[[NSBundle mainBundle] pathForResource:@"JPSImagePickerController" ofType:@"bundle"]];
    });
    return bundle;
}

- (id)initWithDelegate:(id<JPSImagePickerDelegate>)delegate position:(AVCaptureDevicePosition)position {
    self = [self init];
    if (self) {
        self.editingEnabled = YES;
        self.zoomEnabled = YES;
        self.volumeButtonTakesPicture = YES;
        
        self.delegate = delegate;
        self.cameraPosition = position;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.tintColor = [UIColor whiteColor];
    self.view.backgroundColor = [UIColor blackColor];
    self.captureQueue = [[NSOperationQueue alloc] init];
    [self addImageMask];
    [self addCameraButton];
    [self addCancelButton];
    [self addFlashButton];
    [self addCameraSwitchButton];
    self.initialInterfaceOrientation = [[UIApplication sharedApplication] statusBarOrientation];
}




- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    [self enableCapture];
    [self updateFlashButton];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    [self.captureQueue cancelAllOperations];
    [self.capturePreviewLayer removeFromSuperlayer];
    for (AVCaptureInput *input in self.session.inputs) {
        [self.session removeInput:input];
    }
    for (AVCaptureOutput *output in self.session.outputs) {
        [self.session removeOutput:output];
    }
    [self.session stopRunning];
    self.session = nil;
}


/**
 * Forces this image picker class to not rotate interfaces, because the image preview doesn't right itself
 * after rotation, and you have to start dealing with upside-down images
 * This avoids a whole addition layer of complexity in ensuring user is taking WYSIWYG photos
 *
 * WARNING: this method is deprecated in iOS 8, but I'm forced to include it at present for iOS 7 back compatibility
 */
- (NSUInteger)supportedInterfaceOrientations
{
    NSUInteger orientations;
    switch ( self.initialInterfaceOrientation )
    {
        case UIInterfaceOrientationLandscapeLeft:
            orientations = UIInterfaceOrientationMaskLandscapeLeft;
            break;
        case UIInterfaceOrientationLandscapeRight:
            orientations = UIInterfaceOrientationMaskLandscapeRight;
            break;
        case UIInterfaceOrientationUnknown:
        default:
            orientations = UIInterfaceOrientationMaskLandscapeLeft | UIInterfaceOrientationMaskLandscapeRight;;
            break;
    }
    return orientations;
}

#pragma mark - UI

- (void)addCameraButton {
    self.cameraButton = [JPSCameraButton button];
    self.cameraButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.cameraButton addTarget:self action:@selector(takePicture) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.cameraButton];
    
    // Constraints
    NSLayoutConstraint *horizontal = [NSLayoutConstraint constraintWithItem:self.cameraButton
                                                                  attribute:NSLayoutAttributeRight
                                                                  relatedBy:NSLayoutRelationEqual
                                                                     toItem:self.view
                                                                  attribute:NSLayoutAttributeRight
                                                                 multiplier:1.0f
                                                                   constant:-6.5f];
    NSLayoutConstraint *bottom = [NSLayoutConstraint constraintWithItem:self.cameraButton
                                                              attribute:NSLayoutAttributeBottom
                                                              relatedBy:NSLayoutRelationEqual
                                                                 toItem:self.view
                                                              attribute:NSLayoutAttributeBottom
                                                             multiplier:1.0f
                                                               constant:-6.5f];
    NSLayoutConstraint *width = [NSLayoutConstraint constraintWithItem:self.cameraButton
                                                             attribute:NSLayoutAttributeWidth
                                                             relatedBy:NSLayoutRelationEqual
                                                                toItem:nil
                                                             attribute:NSLayoutAttributeNotAnAttribute
                                                            multiplier:1.0f
                                                              constant:66.0f];
    NSLayoutConstraint *height = [NSLayoutConstraint constraintWithItem:self.cameraButton
                                                              attribute:NSLayoutAttributeHeight
                                                              relatedBy:NSLayoutRelationEqual
                                                                 toItem:nil
                                                              attribute:NSLayoutAttributeNotAnAttribute
                                                             multiplier:1.0f
                                                               constant:66.0f];
    [self.view addConstraints:@[horizontal, bottom, width, height]];
}

- (void)addCancelButton {
    self.cancelButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.cancelButton.titleLabel.font = [UIFont systemFontOfSize:18.0f];
    self.cancelButton.translatesAutoresizingMaskIntoConstraints = NO;
    NSString *title = NSLocalizedStringWithDefaultValue(@"cancel", nil, [JPSImagePickerController bundle], @"Cancel", nil);
    [self.cancelButton setTitle:title forState:UIControlStateNormal];
    [self.cancelButton addTarget:self action:@selector(dismiss) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.cancelButton];
    
    NSLayoutConstraint *left = [NSLayoutConstraint constraintWithItem:self.cancelButton
                                                            attribute:NSLayoutAttributeLeft
                                                            relatedBy:NSLayoutRelationEqual
                                                               toItem:self.view
                                                            attribute:NSLayoutAttributeLeft
                                                           multiplier:1.0f
                                                             constant:15.5f];
    NSLayoutConstraint *bottom = [NSLayoutConstraint constraintWithItem:self.cancelButton
                                                              attribute:NSLayoutAttributeBottom
                                                              relatedBy:NSLayoutRelationEqual
                                                                 toItem:self.view
                                                              attribute:NSLayoutAttributeBottom
                                                             multiplier:1.0f
                                                               constant:-19.5f];
    [self.view addConstraints:@[left, bottom]];
}

- (void)addFlashButton {
    self.flashButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.flashButton.translatesAutoresizingMaskIntoConstraints = NO;
    UIImage *flashButtonImage = [[self getBundledImage:@"flash_button"] imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];
    [self.flashButton setImage:flashButtonImage forState:UIControlStateNormal];
    [self.flashButton addTarget:self action:@selector(didPressFlashButton) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.flashButton];
    
    NSLayoutConstraint *left = [NSLayoutConstraint constraintWithItem:self.flashButton
                                                            attribute:NSLayoutAttributeLeft
                                                            relatedBy:NSLayoutRelationEqual
                                                               toItem:self.view
                                                            attribute:NSLayoutAttributeLeft
                                                           multiplier:1.0f
                                                             constant:8.0f];
    NSLayoutConstraint *top = [NSLayoutConstraint constraintWithItem:self.flashButton
                                                           attribute:NSLayoutAttributeTop
                                                           relatedBy:NSLayoutRelationEqual
                                                              toItem:self.view
                                                           attribute:NSLayoutAttributeTop
                                                          multiplier:1.0f
                                                            constant:9.5f];
    [self.view addConstraints:@[left, top]];
}

- (void)addCameraSwitchButton {
    self.cameraSwitchButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.cameraSwitchButton.translatesAutoresizingMaskIntoConstraints = NO;
    UIImage *cameraSwitchImage = [self getBundledImage:@"camera_switch_button"];
    [self.cameraSwitchButton setBackgroundImage:cameraSwitchImage forState:UIControlStateNormal];
    [self.cameraSwitchButton addTarget:self action:@selector(didPressCameraSwitchButton) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.cameraSwitchButton];
    
    NSLayoutConstraint *right = [NSLayoutConstraint constraintWithItem:self.cameraSwitchButton
                                                             attribute:NSLayoutAttributeRight
                                                             relatedBy:NSLayoutRelationEqual
                                                                toItem:self.view
                                                             attribute:NSLayoutAttributeRight
                                                            multiplier:1.0f
                                                              constant:-7.5f];
    NSLayoutConstraint *top = [NSLayoutConstraint constraintWithItem:self.cameraSwitchButton
                                                           attribute:NSLayoutAttributeTop
                                                           relatedBy:NSLayoutRelationEqual
                                                              toItem:self.view
                                                           attribute:NSLayoutAttributeTop
                                                          multiplier:1.0f
                                                            constant:7.5f];
    [self.view addConstraints:@[right, top]];
}

- (BOOL)prefersStatusBarHidden {
    return YES;
}

#pragma mark - AVCapture

- (void)enableCapture {
    if (self.session) return;
    
    self.flashButton.hidden = YES;
    self.cameraSwitchButton.hidden = YES;
    NSBlockOperation *operation = [self captureOperation];
    operation.completionBlock = ^{
        [self operationCompleted];
    };
    operation.queuePriority = NSOperationQueuePriorityVeryHigh;
    [self.captureQueue addOperation:operation];
}

- (NSBlockOperation *)captureOperation {
    NSBlockOperation *operation = [NSBlockOperation blockOperationWithBlock:^{
        self.session = [[AVCaptureSession alloc] init];
        AVCaptureDevice *device = [self activeCamera];
        NSError *error = nil;
        
        AVCaptureDeviceInput *input = [AVCaptureDeviceInput deviceInputWithDevice:device error:&error];
        if (!input) return;
        
        [self.session addInput:input];
        
        // Turn on point autofocus for middle of view
        [device lockForConfiguration:&error];
        if (!error) {
            if ([device isFocusModeSupported:AVCaptureFocusModeContinuousAutoFocus]) {
                device.focusPointOfInterest = CGPointMake(0.5,0.5);
                device.focusMode = AVCaptureFocusModeContinuousAutoFocus;
            }
            if ([device isFlashModeSupported:AVCaptureFlashModeOn]) {
                device.flashMode = AVCaptureFlashModeOn;
            }
        }
        [device unlockForConfiguration];
        
        self.capturePreviewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:self.session];
        
        self.capturePreviewLayer.frame = CGRectMake(0, 0, self.view.bounds.size.width, self.view.bounds.size.height);
        self.capturePreviewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
        [self updateVideoOrientation];
        
        // Still Image Output
        AVCaptureStillImageOutput *stillOutput = [[AVCaptureStillImageOutput alloc] init];
        stillOutput.outputSettings = @{AVVideoCodecKey: AVVideoCodecJPEG};
        [self.session addOutput:stillOutput];
    }];
    return operation;
}

- (void)operationCompleted {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (!self.session) return;
        self.capturePreviewView = [[UIView alloc] initWithFrame:CGRectOffset(self.capturePreviewLayer.frame, 0, 0)];
#if TARGET_IPHONE_SIMULATOR
        self.capturePreviewView.frame = CGRectMake(0, 0, self.view.bounds.size.width, self.view.bounds.size.height - 73.0f);
        self.capturePreviewView.backgroundColor = [UIColor redColor];
#endif
        [self.view insertSubview:self.capturePreviewView atIndex:0];
        [self.capturePreviewView.layer addSublayer:self.capturePreviewLayer];
        [self.view sendSubviewToBack:self.capturePreviewView];
        [self.session startRunning];
        if ([UIImagePickerController isCameraDeviceAvailable:UIImagePickerControllerCameraDeviceFront] &&
            [UIImagePickerController isCameraDeviceAvailable:UIImagePickerControllerCameraDeviceRear]) {
            self.cameraSwitchButton.hidden = NO;
        }
    });
}

- (AVCaptureDevice *)activeCamera {
    return [self cameraForPosition:self.cameraPosition];
}

- (AVCaptureDevice *)cameraForPosition:(AVCaptureDevicePosition)position {
    NSArray *devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    for (AVCaptureDevice *device in devices) {
        if (device.position == position) {
            return device;
        }
    }
    return nil;
}

- (AVCaptureDevice *)currentDevice {
    return [(AVCaptureDeviceInput *)self.session.inputs.firstObject device];
}

#pragma mark - Actions

- (void)takePicture {
    if (!self.cameraButton.enabled) return;
    
    AVCaptureStillImageOutput *output = self.session.outputs.lastObject;
    AVCaptureConnection *videoConnection = output.connections.lastObject;
    if (!videoConnection) {
        [self showPreview];
        return;
    }
    
    self.cameraButton.enabled = NO;

    [output captureStillImageAsynchronouslyFromConnection:videoConnection
                                        completionHandler:^(CMSampleBufferRef imageDataSampleBuffer, NSError *error) {
                                            if (!imageDataSampleBuffer || error) return;
                                            
                                            NSData *imageData = [AVCaptureStillImageOutput jpegStillImageNSDataRepresentation:imageDataSampleBuffer];
                                            
                                            UIImage *rawCameraImage = [UIImage imageWithCGImage:[[[UIImage alloc] initWithData:imageData] CGImage]];
                                            
                                            self.previewImageOrientation = [self formatPreviewImageOrientation];
                                            
                                            if (self.editingEnabled) {
                                                UIImage *rotatedImage = [UIImage rotateImage:rawCameraImage toOrientation:self.previewImageOrientation];
                                                self.previewImage = rotatedImage;
                                                [self showPreview];
                                            }
                                            else {
                                                UIImageOrientation uneditedImageOrientation = [self formatUneditedImageOrientation];
                                                UIImage *uneditedRotatedImage = [UIImage rotateImage:rawCameraImage toOrientation:uneditedImageOrientation];
                                                [self.delegate jpsImagePicker:self didTakePicture:uneditedRotatedImage];
                                            }

                                        }];
}

- (void)dismiss {
    [self.delegate jpsImagePickerDidCancel:self];
}

- (void)updateFlashButton {
    AVCaptureDevice *device = [self currentDevice];
    NSString *flashTitle = nil;
    
    switch (device.flashMode) {
        case AVCaptureFlashModeOn:
            flashTitle = NSLocalizedStringWithDefaultValue(@"flash_on", nil, [JPSImagePickerController bundle], @"Flash On", nil);
            break;
        default:
            flashTitle = NSLocalizedStringWithDefaultValue(@"flash_off", nil, [JPSImagePickerController bundle], @"Flash Off", nil);
            break;
    }
    
    [self.flashButton setTitle:flashTitle forState:UIControlStateNormal];
    self.flashButton.hidden = ![device hasFlash];
}

- (void)didPressFlashButton {
    // Expand to show flash modes
    AVCaptureDevice *device = [self currentDevice];
    NSError *error = nil;
    // Turn on point autofocus for middle of view
    [device lockForConfiguration:&error];
    if (!error) {
        if (device.flashMode == AVCaptureFlashModeOff) {
            device.flashMode = AVCaptureFlashModeOn;
        } else {
            device.flashMode = AVCaptureFlashModeOff;
        }
        
        [self updateFlashButton];
    }
    [device unlockForConfiguration];
}

- (void)didPressCameraSwitchButton {
    if (!self.session) return;
    [self.session stopRunning];
    
    // Input Switch
    NSBlockOperation *operation = [NSBlockOperation blockOperationWithBlock:^{
        switch (self.cameraPosition) {
            case AVCaptureDevicePositionFront:
                self.cameraPosition = AVCaptureDevicePositionBack;
                break;
            default:
                self.cameraPosition = AVCaptureDevicePositionFront;
                break;
        }
        
        AVCaptureDevice *camera = [self activeCamera];
        
        // Should the flash button still be displayed?
        dispatch_async(dispatch_get_main_queue(), ^{
            self.flashButton.hidden = !camera.isFlashAvailable;
        });
        
        // Remove previous camera, and add new
        [self.session removeInput:[self.session.inputs firstObject]];
        NSError *error = nil;
        
        AVCaptureDeviceInput *input = [AVCaptureDeviceInput deviceInputWithDevice:camera error:&error];
        if (!input) return;
        [self.session addInput:input];
    }];
    operation.completionBlock = ^{
        dispatch_async(dispatch_get_main_queue(), ^{
            if (!self.session) return;
            [self.session startRunning];
        });
    };
    operation.queuePriority = NSOperationQueuePriorityVeryHigh;
    [self.captureQueue addOperation:operation];
    
    // Flip Animation
    [UIView transitionWithView:self.capturePreviewView
                      duration:1.0f
                       options:UIViewAnimationOptionTransitionFlipFromLeft | UIViewAnimationOptionAllowAnimatedContent
                    animations:nil
                    completion:nil];
}

#pragma mark - Preview UI

- (void)showPreview {
    self.cameraButton.hidden = YES;
    self.cancelButton.hidden = YES;
    self.flashButton.hidden = YES;
    self.cameraSwitchButton.hidden = YES;
    self.capturePreviewLayer.hidden = YES;
    
    // Preview UI
    [self addPreview];
    [self addRetakeButton];
    [self addUseButton];
    
    // Preview Top Area UI
    [self addConfirmationLabel];
    [self addConfirmationOverlayLabel];
}

- (void)addImageMask {
    CGRect frame;
    if ( self.view.frame.size.width > self.view.frame.size.height )
    {
        frame = CGRectMake(0, 0, self.view.frame.size.width, self.view.frame.size.height);
    }
    else
    {
        frame = CGRectMake(0, 0, self.view.frame.size.height, self.view.frame.size.width);
    }
    self.previewImageMask = [[JPSImageMask alloc] initWithFrame:frame];
    [self.view addSubview:self.previewImageMask];
    self.previewImageMask.userInteractionEnabled = NO;
    
}

- (void)addPreview {
    if (self.previewImageView) {
        self.previewImageView.image = self.previewImage;
        self.previewImageView.hidden = NO;
        if ( self.previewScrollView ) {
            self.previewScrollView.hidden = NO;
        }
        return;
    }

    CGRect previewImageFrame = CGRectMake(0, 0, self.previewImage.size.width, self.previewImage.size.height);
    CGRect previewImageViewFrame = [self fullScreenCenteredRect:previewImageFrame];
    CGRect previewScrollViewFrame = [self fullScreenRect:previewImageFrame];
    
    
    self.previewImageView = [[UIImageView alloc] initWithFrame:previewImageViewFrame];
    self.previewImageView.contentMode = UIViewContentModeScaleAspectFit;
    self.previewImageView.image = self.previewImage;
    self.previewImageView.clipsToBounds = YES;
    
    
    self.previewScrollView = [[UIScrollView alloc] initWithFrame:previewScrollViewFrame];
    self.previewScrollView.backgroundColor = [UIColor blackColor];
    self.previewScrollView.maximumZoomScale = 4.0f;
    self.previewScrollView.minimumZoomScale = 1.0f;
    self.previewScrollView.delegate = self;
    self.previewScrollView.showsHorizontalScrollIndicator = NO;
    self.previewScrollView.showsVerticalScrollIndicator = NO;
    self.previewScrollView.alwaysBounceHorizontal = YES;
    self.previewScrollView.alwaysBounceVertical = YES;
    [self.previewScrollView addSubview:self.previewImageView];
    self.previewScrollView.contentSize = self.previewImageView.frame.size;
    
    self.previewScrollView.userInteractionEnabled = self.zoomEnabled;
    [self.view addSubview:self.previewScrollView];
    [self.view sendSubviewToBack:self.previewImageMask];
    [self.view sendSubviewToBack:self.previewScrollView];
    [self.view sendSubviewToBack:self.capturePreviewView];

}



- (void)addRetakeButton {
    if (self.retakeButton) {
        self.retakeButton.hidden = NO;
        return;
    }
    self.retakeButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.retakeButton.titleLabel.font = [UIFont systemFontOfSize:18.0f];
    self.retakeButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.retakeButton setTitle:NSLocalizedStringWithDefaultValue(@"retake", nil, [JPSImagePickerController bundle], @"Retake", nil)
                       forState:UIControlStateNormal];
    [self.retakeButton addTarget:self action:@selector(retake) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.retakeButton];
    
    NSLayoutConstraint *left = [NSLayoutConstraint constraintWithItem:self.retakeButton
                                                            attribute:NSLayoutAttributeLeft
                                                            relatedBy:NSLayoutRelationEqual
                                                               toItem:self.view
                                                            attribute:NSLayoutAttributeLeft
                                                           multiplier:1.0f
                                                             constant:15.5f];
    NSLayoutConstraint *bottom = [NSLayoutConstraint constraintWithItem:self.retakeButton
                                                              attribute:NSLayoutAttributeBottom
                                                              relatedBy:NSLayoutRelationEqual
                                                                 toItem:self.view
                                                              attribute:NSLayoutAttributeBottom
                                                             multiplier:1.0f
                                                               constant:-19.5f];
    [self.view addConstraints:@[left, bottom]];
}

- (void)addUseButton {
    if (self.useButton) {
        self.useButton.hidden = NO;
        return;
    }
    self.useButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.useButton.titleLabel.font = [UIFont systemFontOfSize:18.0f];
    self.useButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.useButton setTitle:NSLocalizedStringWithDefaultValue(@"use", nil, [JPSImagePickerController bundle], @"Use", nil)
                    forState:UIControlStateNormal];
    [self.useButton addTarget:self action:@selector(use) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.useButton];
    
    NSLayoutConstraint *right = [NSLayoutConstraint constraintWithItem:self.useButton
                                                             attribute:NSLayoutAttributeRight
                                                             relatedBy:NSLayoutRelationEqual
                                                                toItem:self.view
                                                             attribute:NSLayoutAttributeRight
                                                            multiplier:1.0f
                                                              constant:-15.5f];
    NSLayoutConstraint *bottom = [NSLayoutConstraint constraintWithItem:self.useButton
                                                              attribute:NSLayoutAttributeBottom
                                                              relatedBy:NSLayoutRelationEqual
                                                                 toItem:self.view
                                                              attribute:NSLayoutAttributeBottom
                                                             multiplier:1.0f
                                                               constant:-19.5f];
    [self.view addConstraints:@[right, bottom]];
}

- (UIView *)viewForZoomingInScrollView:(UIScrollView *)scrollView {
    return self.previewImageView;
}

#pragma mark - Preview Top Area UI

- (void)addConfirmationLabel {
    if (self.confirmationLabel) {
        self.confirmationLabel.text = self.confirmationString;
        self.confirmationLabel.hidden = NO;
        return;
    }
    self.confirmationLabel = [[UILabel alloc] init];
    self.confirmationLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.confirmationLabel.numberOfLines = 0;
    self.confirmationLabel.textAlignment = NSTextAlignmentCenter;
    self.confirmationLabel.font = [UIFont systemFontOfSize:16.0f];
    self.confirmationLabel.textColor = [UIColor whiteColor];
    self.confirmationLabel.text = self.confirmationString;
    [self.view addSubview:self.confirmationLabel];
    
    NSLayoutConstraint *centerX = [NSLayoutConstraint constraintWithItem:self.confirmationLabel
                                                               attribute:NSLayoutAttributeCenterX
                                                               relatedBy:NSLayoutRelationEqual
                                                                  toItem:self.view
                                                               attribute:NSLayoutAttributeCenterX
                                                              multiplier:1.0f
                                                                constant:0];
    NSLayoutConstraint *width = [NSLayoutConstraint constraintWithItem:self.confirmationLabel
                                                             attribute:NSLayoutAttributeWidth
                                                             relatedBy:NSLayoutRelationEqual
                                                                toItem:self.view
                                                             attribute:NSLayoutAttributeWidth
                                                            multiplier:0.9f
                                                              constant:0];
    NSLayoutConstraint *top = [NSLayoutConstraint constraintWithItem:self.confirmationLabel
                                                           attribute:NSLayoutAttributeTop
                                                           relatedBy:NSLayoutRelationEqual
                                                              toItem:self.view
                                                           attribute:NSLayoutAttributeTop
                                                          multiplier:1.0f
                                                            constant:9.5f];
    [self.view addConstraints:@[centerX, width, top]];
}

- (void)addConfirmationOverlayLabel {
    if (self.confirmationOverlayLabel) {
        self.confirmationOverlayLabel.text = self.confirmationOverlayString;
        self.confirmationOverlayLabel.hidden = NO;
        return;
    }
    self.confirmationOverlayLabel = [[UILabel alloc] init];
    self.confirmationOverlayLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.confirmationOverlayLabel.numberOfLines = 0;
    self.confirmationOverlayLabel.textAlignment = NSTextAlignmentCenter;
    self.confirmationOverlayLabel.font = [UIFont systemFontOfSize:16.0f];
    self.confirmationOverlayLabel.textColor = [UIColor whiteColor];
    self.confirmationOverlayLabel.backgroundColor = self.confirmationOverlayBackgroundColor;
    self.confirmationOverlayLabel.text = self.confirmationOverlayString;
    [self.view addSubview:self.confirmationOverlayLabel];
    
    NSLayoutConstraint *centerX = [NSLayoutConstraint constraintWithItem:self.confirmationOverlayLabel
                                                               attribute:NSLayoutAttributeCenterX
                                                               relatedBy:NSLayoutRelationEqual
                                                                  toItem:self.view
                                                               attribute:NSLayoutAttributeCenterX
                                                              multiplier:1.0f
                                                                constant:0];
    NSLayoutConstraint *width = [NSLayoutConstraint constraintWithItem:self.confirmationOverlayLabel
                                                             attribute:NSLayoutAttributeWidth
                                                             relatedBy:NSLayoutRelationEqual
                                                                toItem:self.view
                                                             attribute:NSLayoutAttributeWidth
                                                            multiplier:1.0f
                                                              constant:0];
    NSLayoutConstraint *top = [NSLayoutConstraint constraintWithItem:self.confirmationOverlayLabel
                                                           attribute:NSLayoutAttributeTop
                                                           relatedBy:NSLayoutRelationEqual
                                                              toItem:self.capturePreviewView
                                                           attribute:NSLayoutAttributeTop
                                                          multiplier:1.0f
                                                            constant:0];
    [self.view addConstraints:@[centerX, width, top]];
}

- (void)setConfirmationString:(NSString *)confirmationString {
    _confirmationString = confirmationString;
    if (self.confirmationLabel) {
        self.confirmationLabel.text = self.confirmationString;
    }
}

- (void)setConfirmationOverlayString:(NSString *)confirmationOverlayString {
    _confirmationOverlayString = confirmationOverlayString;
    if (self.confirmationOverlayLabel) {
        self.confirmationOverlayLabel.text = self.confirmationOverlayString;
    }
}

- (void)setConfirmationOverlayBackgroundColor:(UIColor *)confirmationOverlayBackgroundColor {
    _confirmationOverlayBackgroundColor = confirmationOverlayBackgroundColor;
    if (self.confirmationOverlayLabel) {
        self.confirmationOverlayLabel.backgroundColor = confirmationOverlayBackgroundColor;
    }
}

#pragma mark - Preview Actions

- (void)retake {
    self.previewImageView.hidden = YES;
    self.retakeButton.hidden = YES;
    self.useButton.hidden = YES;
    
    self.confirmationLabel.hidden = YES;
    self.confirmationOverlayLabel.hidden = YES;
    
    self.cameraButton.hidden = NO;
    self.cancelButton.hidden = NO;
    self.cameraSwitchButton.hidden = NO;
    self.capturePreviewLayer.hidden = NO;
    
    self.cameraButton.enabled = YES;
    self.previewScrollView.hidden = YES;
    [self updateFlashButton];
}

- (void)use {
    UIImageOrientation finalImageOrientation = [self finalImageOrientation];
    
    UIImage *finalImage = [UIImage rotateImage:self.previewImage toOrientation:finalImageOrientation];
    
    [self.delegate jpsImagePicker:self didConfirmPicture:finalImage];
}

- (UIImage *)getBundledImage:(NSString *)imageName {
    NSBundle *imagePickerBundle = [JPSImagePickerController bundle];
    NSURL *flashImagePathURL = [imagePickerBundle URLForResource:imageName withExtension:@"png"];
    return [UIImage imageWithContentsOfFile:flashImagePathURL.path];
}



#pragma mark - Image frame to bounds frame


/**
 *  Converted any rect with a different aspect ration than device screen to full-screen and centers it,
 *  while preserving original aspect ratio
 */
- (CGRect)fullScreenCenteredRect:(CGRect)inputRect
{
    CGRect fullScreenRect = CGRectMake(0, 0, self.view.bounds.size.width, self.view.bounds.size.height);
    
    CGFloat imageAspectRatio = inputRect.size.width / inputRect.size.height;
    CGFloat viewAspectRatio = fullScreenRect.size.width / fullScreenRect.size.width;
    
    CGFloat xPos = 0;
    CGFloat yPos = 0;
    CGFloat width = 0;
    CGFloat height = 0;
    CGFloat sizeRatio = 0;
    if ( imageAspectRatio > viewAspectRatio )
    {
        sizeRatio = fullScreenRect.size.height / inputRect.size.height ;
        width = inputRect.size.width * sizeRatio;
        height = fullScreenRect.size.height;
        xPos = ( fullScreenRect.size.width - width ) / 2;
        yPos = 0;

    }
    else
    {
        sizeRatio = fullScreenRect.size.width / inputRect.size.width;
        width = fullScreenRect.size.width;
        height = inputRect.size.height * sizeRatio;
        xPos = 0;
        yPos = ( fullScreenRect.size.height - height ) / 2;
    }
    
    return CGRectMake(xPos, yPos, width, height);
}

/**
 *  Converted any rect with a different aspect ration than device screen to full-screen and centers it,
 *  while preserving original aspect ratio
 */
- (CGRect)fullScreenRect:(CGRect)inputRect
{
    CGRect fullScreenRect = CGRectMake(0, 0, self.view.bounds.size.width, self.view.bounds.size.height);
    
    CGFloat imageAspectRatio = inputRect.size.width / inputRect.size.height;
    CGFloat viewAspectRatio = fullScreenRect.size.width / fullScreenRect.size.height;
    
    CGFloat width = 0;
    CGFloat height = 0;
    CGFloat sizeRatio = 0;
    if ( imageAspectRatio > viewAspectRatio )
    {
        sizeRatio = fullScreenRect.size.height / inputRect.size.height ;
        width = inputRect.size.width * sizeRatio;
        height = fullScreenRect.size.height;
    }
    else
    {
        sizeRatio = fullScreenRect.size.width / inputRect.size.width;
        width = fullScreenRect.size.width;
        height = inputRect.size.height * sizeRatio;
    }
    
    return CGRectMake(0, 0, width, height);
}




#pragma mark - Orientation

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    [self updateVideoOrientation];
}

- (void)updateVideoOrientation {
    self.capturePreviewLayer.connection.videoOrientation = [self currentVideoOrientation];
}



- (AVCaptureVideoOrientation)currentVideoOrientation {
    UIInterfaceOrientation deviceOrientation = [[UIApplication sharedApplication] statusBarOrientation];
    switch (deviceOrientation) {
        case UIInterfaceOrientationPortraitUpsideDown:
            return AVCaptureVideoOrientationPortraitUpsideDown;
        case UIInterfaceOrientationLandscapeLeft:
            return AVCaptureVideoOrientationLandscapeLeft;
        case UIInterfaceOrientationLandscapeRight:
            return AVCaptureVideoOrientationLandscapeRight;
        case UIInterfaceOrientationPortrait:
        default:
            return AVCaptureVideoOrientationPortrait;
    }
}





#pragma mark - Image Preview Orientation

- (UIImageOrientation)formatPreviewImageOrientation {
    UIImageOrientation returnImageOrientation;
    if ( self.cameraPosition == AVCaptureDevicePositionFront )
    {
        returnImageOrientation = [self frontCameraPreviewImageOrientation];
    }
    else
    {
        returnImageOrientation = [self backCameraPreviewImageOrientation];
    }
    return returnImageOrientation;
}

- (UIImageOrientation)frontCameraPreviewImageOrientation
{
    self.previewDeviceOrientation = [UIDevice currentDevice].orientation;
    return  (self.initialInterfaceOrientation == UIInterfaceOrientationLandscapeLeft) ? UIImageOrientationUpMirrored : UIImageOrientationDownMirrored;
}

- (UIImageOrientation)backCameraPreviewImageOrientation
{
    self.previewDeviceOrientation = [UIDevice currentDevice].orientation;
    return  (self.initialInterfaceOrientation == UIInterfaceOrientationLandscapeLeft) ? UIImageOrientationDown : UIImageOrientationUp;
}




#pragma mark - Image Unediting Orientation

- (UIImageOrientation)formatUneditedImageOrientation {
    UIImageOrientation returnImageOrientation;
    if ( self.cameraPosition == AVCaptureDevicePositionFront )
    {
        returnImageOrientation = [self frontCameraUneditedImageOrientation];
    }
    else
    {
        returnImageOrientation = [self backCameraUneditedImageOrientation];
    }
    return returnImageOrientation;
}

- (UIImageOrientation)frontCameraUneditedImageOrientation
{
    UIImageOrientation returnImageOrientation;
    switch (self.previewDeviceOrientation) {
        case UIDeviceOrientationLandscapeLeft:
            returnImageOrientation = (self.initialInterfaceOrientation == UIInterfaceOrientationLandscapeLeft) ? UIImageOrientationDownMirrored : UIImageOrientationDownMirrored;
            break;
        case UIDeviceOrientationLandscapeRight:
            returnImageOrientation = (self.initialInterfaceOrientation == UIInterfaceOrientationLandscapeLeft) ? UIImageOrientationUpMirrored : UIImageOrientationUpMirrored;
            break;
        case UIDeviceOrientationPortraitUpsideDown:
            returnImageOrientation = (self.initialInterfaceOrientation == UIInterfaceOrientationLandscapeLeft) ? UIImageOrientationRightMirrored : UIImageOrientationLeft;
            break;
        case UIDeviceOrientationPortrait:
        default:
            returnImageOrientation = (self.initialInterfaceOrientation == UIInterfaceOrientationLandscapeLeft) ? UIImageOrientationLeftMirrored : UIImageOrientationRight;
            break;
    }
    return returnImageOrientation;
}

- (UIImageOrientation)backCameraUneditedImageOrientation
{
    UIImageOrientation returnImageOrientation;
    switch (self.previewDeviceOrientation) {
        case UIDeviceOrientationLandscapeLeft:
            returnImageOrientation = (self.initialInterfaceOrientation == UIInterfaceOrientationLandscapeLeft) ? UIImageOrientationUp : UIImageOrientationUp;
            break;
        case UIDeviceOrientationLandscapeRight:
            returnImageOrientation = (self.initialInterfaceOrientation == UIInterfaceOrientationLandscapeLeft) ? UIImageOrientationDown : UIImageOrientationDown;
            break;
        case UIDeviceOrientationPortraitUpsideDown:
            returnImageOrientation = (self.initialInterfaceOrientation == UIInterfaceOrientationLandscapeLeft) ? UIImageOrientationLeft : UIImageOrientationLeft;
            break;
        case UIDeviceOrientationPortrait:
        default:
            returnImageOrientation = (self.initialInterfaceOrientation == UIInterfaceOrientationLandscapeLeft) ? UIImageOrientationRight : UIImageOrientationRight;
            break;
    }
    return returnImageOrientation;
}






#pragma mark - Image Final Orientation

- (UIImageOrientation)finalImageOrientation {
    UIImageOrientation returnImageOrientation;
    if ( self.cameraPosition == AVCaptureDevicePositionFront )
    {
        returnImageOrientation = [self frontCameraFinalImageOrientation];
    }
    else
    {
        returnImageOrientation = [self backCameraFinalImageOrientation];
    }
    return returnImageOrientation;
}

- (UIImageOrientation)frontCameraFinalImageOrientation
{
    UIImageOrientation returnImageOrientation;
    switch (self.previewDeviceOrientation) {
        case UIDeviceOrientationLandscapeLeft:
            returnImageOrientation = (self.initialInterfaceOrientation == UIInterfaceOrientationLandscapeLeft) ? UIImageOrientationDown : UIImageOrientationUp;
            break;
        case UIDeviceOrientationLandscapeRight:
            returnImageOrientation = (self.initialInterfaceOrientation == UIInterfaceOrientationLandscapeLeft) ? UIImageOrientationUp : UIImageOrientationDown;
            break;
        case UIDeviceOrientationPortraitUpsideDown:
            returnImageOrientation = (self.initialInterfaceOrientation == UIInterfaceOrientationLandscapeLeft) ? UIImageOrientationRight : UIImageOrientationLeft;
            break;
        case UIDeviceOrientationPortrait:
        default:
            returnImageOrientation = (self.initialInterfaceOrientation == UIInterfaceOrientationLandscapeLeft) ? UIImageOrientationLeft : UIImageOrientationRight;
            break;
    }
    return returnImageOrientation;
}

- (UIImageOrientation)backCameraFinalImageOrientation
{
    UIImageOrientation returnImageOrientation;
    switch (self.previewDeviceOrientation) {
        case UIDeviceOrientationLandscapeLeft:
            returnImageOrientation = (self.initialInterfaceOrientation == UIInterfaceOrientationLandscapeLeft) ? UIImageOrientationDown : UIImageOrientationUp;
            break;
        case UIDeviceOrientationLandscapeRight:
            returnImageOrientation = (self.initialInterfaceOrientation == UIInterfaceOrientationLandscapeLeft) ? UIImageOrientationUp : UIImageOrientationDown;
            break;
        case UIDeviceOrientationPortraitUpsideDown:
            returnImageOrientation = (self.initialInterfaceOrientation == UIInterfaceOrientationLandscapeLeft) ? UIImageOrientationRight : UIImageOrientationLeft;
            break;
        case UIDeviceOrientationPortrait:
        default:
            returnImageOrientation = (self.initialInterfaceOrientation == UIInterfaceOrientationLandscapeLeft) ? UIImageOrientationLeft : UIImageOrientationRight;
            break;
    }
    return returnImageOrientation;
}



@end
