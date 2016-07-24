//
//  NewImageViewController.swift
//  ImageViewer
//
//  Created by Kristian Angyal on 15/07/2016.
//  Copyright © 2016 MailOnline. All rights reserved.
//

import UIKit

class NewImageViewController: UIViewController, ItemController, UIGestureRecognizerDelegate, UIScrollViewDelegate {

    //UI
    var imageView = UIImageView()
    let scrollView = UIScrollView()

    //DELEGATE / DATASOURCE
    var delegate: ItemControllerDelegate?
    var displacedViewsDatasource: GalleryDisplacedViewsDatasource?

    //STATE
    let index: Int
    var isInitialController = false
    let fetchImageBlock: FetchImage
    let itemCount: Int

    //CONFIGURATION
    private var presentationStyle = GalleryPresentationStyle.Displace
    private var zoomDuration = 0.2
    private var displacementDuration: NSTimeInterval = 0.6
    private var displacementTimingCurve: UIViewAnimationCurve = .Linear
    private var displacementSpringBounce: CGFloat = 0.7
    private var overlayAccelerationFactor: CGFloat = 1
    private let minimumZoomScale: CGFloat = 1
    private var maximumZoomScale: CGFloat = 4
    private var pagingMode: GalleryPagingMode = .Standard
    
    /// INTERACTIONS
    private let singleTapRecognizer = UITapGestureRecognizer()
    private let doubleTapRecognizer = UITapGestureRecognizer()
    private let swipeToDismissRecognizer = UIPanGestureRecognizer()
    
    init(index: Int, itemCount: Int, fetchImageBlock: FetchImage, configuration: GalleryConfiguration, isInitialController: Bool = false) {

        self.index = index
        self.itemCount = itemCount
        self.fetchImageBlock = fetchImageBlock
        self.isInitialController = isInitialController

        for item in configuration {

            switch item {
                
            case .DoubleTapToZoomDuration(let duration):    zoomDuration = duration
            case .PresentationStyle(let style):             presentationStyle = style
            case .PagingMode(let mode):                     pagingMode = mode
            case .DisplacementDuration(let duration):       displacementDuration = duration
            case .DisplacementTimingCurve(let curve):       displacementTimingCurve = curve
            case .OverlayAccelerationFactor(let factor):    overlayAccelerationFactor = factor
            case .MaximumZoolScale(let scale):              maximumZoomScale = scale
            case .DisplacementTransitionStyle(let style):

            switch style {

                case .SpringBounce(let bounce):             displacementSpringBounce = bounce
                case .Normal:                               displacementSpringBounce = 1
                }

            default: break
            }
        }

        super.init(nibName: nil, bundle: nil)

        self.modalPresentationStyle = .Custom

        self.imageView.hidden = isInitialController

        configureScrollView()
        configureGestureRecognizers()
    }

    @available (*, unavailable)
    required init?(coder aDecoder: NSCoder) { fatalError() }

    private func configureScrollView() {

        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.decelerationRate = UIScrollViewDecelerationRateFast
        scrollView.contentInset = UIEdgeInsetsZero
        scrollView.contentOffset = CGPointZero
        scrollView.minimumZoomScale = minimumZoomScale
        scrollView.maximumZoomScale = maximumZoomScale
        
        scrollView.delegate = self

        imageView.layer.borderWidth = 1
        imageView.layer.borderColor = UIColor.redColor().CGColor
    }
    
    func configureGestureRecognizers() {
        
        singleTapRecognizer.addTarget(self, action: #selector(scrollViewDidSingleTap))
        singleTapRecognizer.numberOfTapsRequired = 1
        scrollView.addGestureRecognizer(singleTapRecognizer)
        
        doubleTapRecognizer.addTarget(self, action: #selector(scrollViewDidDoubleTap(_:)))
        doubleTapRecognizer.numberOfTapsRequired = 2
        scrollView.addGestureRecognizer(doubleTapRecognizer)
        
        singleTapRecognizer.requireGestureRecognizerToFail(doubleTapRecognizer)
        
        swipeToDismissRecognizer.addTarget(self, action: #selector(scrollViewDidSwipeToDismiss))
        swipeToDismissRecognizer.delegate = self
        view.addGestureRecognizer(swipeToDismissRecognizer)
    }

    private func createViewHierarchy() {

        self.view.addSubview(scrollView)
        scrollView.addSubview(imageView)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        self.view.backgroundColor = UIColor.blueColor().colorWithAlphaComponent(0.8)

        createViewHierarchy()

        fetchImageBlock { [weak self] image in //DON'T Forget offloading the main thread

            if let image = image {

                self?.imageView.image = image
                print(image.size)
            }
        }
    }

    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        
        self.delegate?.itemControllerDidAppear(self)
    }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        scrollView.frame = self.view.bounds

        imageView.bounds.size = aspectFitSize(forContentOfSize: imageView.image!.size, inBounds: self.scrollView.bounds.size)
        scrollView.contentSize = imageView.bounds.size

        imageView.center = scrollView.boundsCenter
    }

    func viewForZoomingInScrollView(scrollView: UIScrollView) -> UIView? {
        
        return imageView
    }
    
    func scrollViewDidZoom(scrollView: UIScrollView) {
        
        imageView.center = contentCenter(forBoundingSize: scrollView.bounds.size, contentSize: scrollView.contentSize)
    }
    
    func scrollViewDidSingleTap() {
        
        self.delegate?.itemControllerDidSingleTap(self)
    }
    
    func scrollViewDidDoubleTap(recognizer: UITapGestureRecognizer) {
        
        let touchPoint = recognizer.locationOfTouch(0, inView: imageView)
        let aspectFillScale = aspectFillZoomScale(forBoundingSize: scrollView.bounds.size, contentSize: imageView.bounds.size)
        
        if (scrollView.zoomScale == 1.0 || scrollView.zoomScale > aspectFillScale) {
            
            let zoomRectangle = zoomRect(ForScrollView: scrollView, scale: aspectFillScale, center: touchPoint)
            
            UIView.animateWithDuration(zoomDuration, animations: {
                self.scrollView.zoomToRect(zoomRectangle, animated: false)
            })
        }
        else  {
            UIView.animateWithDuration(zoomDuration, animations: {
                self.scrollView.setZoomScale(1.0, animated: false)
            })
        }
    }
    
    func scrollViewDidSwipeToDismiss() {
        
    }
    
    func presentItem(alongsideAnimation alongsideAnimation: Duration -> Void) {

        alongsideAnimation(displacementDuration * Double(overlayAccelerationFactor))

        switch presentationStyle {

        case .FadeIn:

            imageView.alpha = 0
            imageView.hidden = false
            UIView.animateWithDuration(displacementDuration) { [weak self] in

                self?.imageView.alpha = 1
            }

        case .Displace:

            //Get the displaced view
            guard let displacedView = displacedViewsDatasource?.provideDisplacementItem(atIndex: index) as? UIImageView,
                let image = displacedView.image else { return }

            //Prepare the animated image view
            let animatedImageView = displacedView.clone()
            animatedImageView.frame = displacedView.frame(inCoordinatesOfView: self.view)
            animatedImageView.clipsToBounds = true
            self.view.addSubview(animatedImageView)

            displacedView.hidden = true

            UIView.animateWithDuration(displacementDuration, delay: 0, usingSpringWithDamping: displacementSpringBounce, initialSpringVelocity: 1, options: UIViewAnimationOptions.CurveEaseIn, animations: {

                if UIApplication.isPortraitOnly == true {
                    animatedImageView.transform = rotationTransform()
                }
                /// Animate it into the center (with optionaly rotating) - that basically includes changing the size and position

                let boundingSize = rotationAdjustedBounds().size
                let aspectFitSize = aspectFitContentSize(forBoundingSize: boundingSize, contentSize: image.size)

                animatedImageView.bounds.size = aspectFitSize
                animatedImageView.center = self.view.boundsCenter

                }, completion: { _ in

                    self.imageView.hidden = false
                    animatedImageView.removeFromSuperview()
            })
        }
    }
    
    ///This resolves which of the two pan gesture recognizers should kick in. There is one built in the GalleryViewController (as it is a UIPageViewController subclass), and another one is added as part of item controller. When we pan, we need to decide whether it constitutes a horizontal paging gesture, or a swipe-to-dismiss gesture.
    /// All the logic is from the perspective of SwipeToDismissRecognizer - should it kick in (or let the paging recognizer page)?
    func gestureRecognizerShouldBegin(gestureRecognizer: UIGestureRecognizer) -> Bool {
        
        /// We only care about the swipe to dismiss gesture recognizer, not the built-in pan recogizner that handles paging.
        guard gestureRecognizer == swipeToDismissRecognizer else { return false }
        
        /// The velocity vector will help us make the right decision
        let velocity = swipeToDismissRecognizer.velocityInView(swipeToDismissRecognizer.view)
        ///A bit of paranoia
        guard velocity.orientation != .None else { return false }
        
        /// We continue if the swipe is horizontal, otherwise it's Vertical and it is swipe to dismiss.
        guard velocity.orientation == .Horizontal else { return true }
        
        /// A special case for horizontal "swipe to dismiss" is when the gallery has carousel mode OFF, then it is possible to reach the beginning or the end of image set while paging. PAging will stop at index = 0 or at index.max. In this case we allow to jump out from the gallery also via horizontal swipe to dismiss.
        if (self.index == 0 && velocity.direction == .Right) || (self.index == self.itemCount - 1 && velocity.direction == .Left) {
            
            return (pagingMode == .Standard)
        }
        
        return false
    }
}
