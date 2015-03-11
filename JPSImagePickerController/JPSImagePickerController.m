//
//  JPSImagePickerController.m
//  JPSImagePickerController
//
//  Created by JP Simard on 1/31/2014.
//  Copyright (c) 2014 JP Simard. All rights reserved.
//

#import "JPSImagePickerController.h"
#import "JPSCameraButton.h"
#import "JPSVolumeButtonHandler.h"

@interface JPSImagePickerController () <UIScrollViewDelegate>

// Camera
@property (nonatomic, strong) AVCaptureSession           * session;
@property (nonatomic, strong) UIView                     * capturePreviewView;
@property (nonatomic, strong) AVCaptureVideoPreviewLayer * capturePreviewLayer;
@property (nonatomic, strong) NSOperationQueue           * captureQueue;
@property (nonatomic, assign) UIImageOrientation           imageOrientation;
@property (nonatomic, assign) AVCaptureDevicePosition      cameraPosition;

// Camera Controls
@property (nonatomic, strong) UIButton *cameraButton;
@property (nonatomic, strong) UIButton *cancelButton;
@property (nonatomic, strong) UIButton *flashButton;
@property (nonatomic, strong) UIButton *cameraSwitchButton;
@property (nonatomic, strong) JPSVolumeButtonHandler *volumeButtonHandler;

// Preview
@property (nonatomic, strong) UIImage     * previewImage;
@property (nonatomic, strong) UIImageView * previewImageView;
@property (nonatomic, strong) UIButton    * retakeButton;
@property (nonatomic, strong) UIButton    * useButton;

// Preview Top Area
@property (nonatomic, strong) UILabel * confirmationLabel;
@property (nonatomic, strong) UILabel * confirmationOverlayLabel;

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
    [self addCameraButton];
    [self addCancelButton];
    [self addFlashButton];
    [self addCameraSwitchButton];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    [self enableCapture];
    [self updateFlashButton];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self addVolumeButtonHandler];
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
    self.volumeButtonHandler = nil;
}

- (void)addVolumeButtonHandler {
    if (self.volumeButtonTakesPicture) {
        self.volumeButtonHandler = [JPSVolumeButtonHandler volumeButtonHandlerWithUpBlock:^{
            [self takePicture];
        } downBlock:nil];
    }
}

#pragma mark - UI

- (void)addCameraButton {
    self.cameraButton = [JPSCameraButton button];
    self.cameraButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.cameraButton addTarget:self action:@selector(takePicture) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.cameraButton];
    
    // Constraints
    NSLayoutConstraint *horizontal = [NSLayoutConstraint constraintWithItem:self.cameraButton
                                                                  attribute:NSLayoutAttributeCenterX
                                                                  relatedBy:NSLayoutRelationEqual
                                                                     toItem:self.view
                                                                  attribute:NSLayoutAttributeCenterX
                                                                 multiplier:1.0f
                                                                   constant:0];
    NSLayoutConstraint *bottom = [NSLayoutConstraint constraintWithItem:self.cameraButton
                                                              attribute:NSLayoutAttributeBottom
                                                              relatedBy:NSLayoutRelationEqual
                                                                 toItem:self.view
                                                              attribute:NSLayoutAttributeBottom
                                                             multiplier:1.0f
                                                               constant:-3.5f];
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
        self.capturePreviewLayer.frame = CGRectMake(0, 0, self.view.bounds.size.width, self.view.bounds.size.height - 69.0f - 73.0f);
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
        self.capturePreviewView = [[UIView alloc] initWithFrame:CGRectOffset(self.capturePreviewLayer.frame, 0, 69.0f)];
#if TARGET_IPHONE_SIMULATOR
        self.capturePreviewView.frame = CGRectMake(0, 0, self.view.bounds.size.width, self.view.bounds.size.height - 73.0f);
        self.capturePreviewView.backgroundColor = [UIColor redColor];
#endif
        [self.view insertSubview:self.capturePreviewView atIndex:0];
        [self.capturePreviewView.layer addSublayer:self.capturePreviewLayer];
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
                                            UIImage *image = [UIImage imageWithCGImage:[[[UIImage alloc] initWithData:imageData] CGImage]
                                                                                 scale:1.0f
                                                                           orientation:[self currentImageOrientation]];
                                            self.previewImage = image;
                                            if (self.editingEnabled) {
                                                [self showPreview];
                                            }
                                            
                                            [self.delegate jpsImagePicker:self didTakePicture:image];
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

- (void)addPreview {
    if (self.previewImageView) {
        self.previewImageView.image = self.previewImage;
        self.previewImageView.hidden = NO;
        return;
    }
    self.previewImageView = [[UIImageView alloc] initWithFrame:self.capturePreviewView.bounds];
    self.previewImageView.contentMode = UIViewContentModeScaleAspectFit;
    self.previewImageView.image = self.previewImage;
    self.previewImageView.clipsToBounds = YES;
    
    UIScrollView *previewScrollView = [[UIScrollView alloc] initWithFrame:self.capturePreviewView.frame];
    previewScrollView.maximumZoomScale = 4.0f;
    previewScrollView.minimumZoomScale = 1.0f;
    previewScrollView.delegate = self;
    previewScrollView.showsHorizontalScrollIndicator = NO;
    previewScrollView.showsVerticalScrollIndicator = NO;
    previewScrollView.alwaysBounceHorizontal = YES;
    previewScrollView.alwaysBounceVertical = YES;
    [previewScrollView addSubview:self.previewImageView];
    previewScrollView.contentSize = self.previewImageView.frame.size;
    previewScrollView.userInteractionEnabled = self.zoomEnabled;
    [self.view addSubview:previewScrollView];
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
    [self updateFlashButton];
}

- (void)use {
    [self.delegate jpsImagePicker:self didConfirmPicture:self.previewImage];
}

- (UIImage *)getBundledImage:(NSString *)imageName {
    NSBundle *imagePickerBundle = [JPSImagePickerController bundle];
    NSURL *flashImagePathURL = [imagePickerBundle URLForResource:imageName withExtension:@"png"];
    return [UIImage imageWithContentsOfFile:flashImagePathURL.path];
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

- (UIImageOrientation)currentImageOrientation {
    UIInterfaceOrientation deviceOrientation = [[UIApplication sharedApplication] statusBarOrientation];
    
    switch (deviceOrientation) {
        case UIInterfaceOrientationLandscapeLeft:
            if (self.cameraPosition == AVCaptureDevicePositionFront) {
                return UIImageOrientationUpMirrored;
            } else {
                return UIImageOrientationDown;
            }
        case UIInterfaceOrientationLandscapeRight:
            if (self.cameraPosition == AVCaptureDevicePositionFront) {
                return UIImageOrientationDownMirrored;
            } else {
                return UIImageOrientationUp;
            }
        case UIInterfaceOrientationPortraitUpsideDown:
            if (self.cameraPosition == AVCaptureDevicePositionFront) {
                return UIImageOrientationLeftMirrored;
            } else {
                return UIImageOrientationRight;
            }
        default:
            if (self.cameraPosition == AVCaptureDevicePositionFront) {
                return UIImageOrientationRightMirrored;
            } else {
                return UIImageOrientationLeft;
            }
    }
}

@end
