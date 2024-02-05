import UIKit
import RoomPlan
import AVFoundation

class RoomCaptureViewController: UIViewController, RoomCaptureViewDelegate, RoomCaptureSessionDelegate {
    
    @IBOutlet var exportButton: UIButton?
    
    @IBOutlet var doneButton: UIBarButtonItem?
    @IBOutlet var cancelButton: UIBarButtonItem?
    @IBOutlet var activityIndicator: UIActivityIndicatorView?
    
    private var isScanning: Bool = false
    
    private var roomCaptureView: RoomCaptureView!
    private var roomCaptureSessionConfig: RoomCaptureSession.Configuration = RoomCaptureSession.Configuration()
    
    private var finalResults: CapturedRoom?
    private var hapticFeedbackCount = 0

    
    private var timer: Timer?
    private var beepTimer: Timer?

    private var interval: TimeInterval = 5
    private var soundInterval: TimeInterval = 5
    private var distance: Double = 5
    
    private var audioPlayer: AVAudioPlayer?
    private let beepSoundURL: URL? = Bundle.main.url(forResource: "beep", withExtension: "mp3")

    
    // Update the timer based on the current interval
    private func updateTimer() {
        // Invalidate the existing timers if they exist
        timer?.invalidate()
        beepTimer?.invalidate()

        // Schedule new timer for haptic feedback
        timer = Timer.scheduledTimer(timeInterval: interval, target: self, selector: #selector(triggerHapticFeedback), userInfo: nil, repeats: true)

        // Schedule beep timer if distance is less than 5
        if distance < 5.0 {
            beepTimer = Timer.scheduledTimer(timeInterval: soundInterval, target: self, selector: #selector(playBeepSound), userInfo: nil, repeats: true)
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupRoomCaptureView()
        activityIndicator?.stopAnimating()
        setupAudioPlayer() // Initialize audio player
    }
    
    private func setupRoomCaptureView() {
        roomCaptureView = RoomCaptureView(frame: view.bounds)
        roomCaptureView.captureSession.delegate = self
        roomCaptureView.delegate = self
        
        view.insertSubview(roomCaptureView, at: 0)
    }
    
    private func setupAudioPlayer() {
        if let url = beepSoundURL {
            do {
                audioPlayer = try AVAudioPlayer(contentsOf: url)
                audioPlayer?.prepareToPlay()
            } catch {
                print("Audio player setup failed: \(error)")
            }
        } else {
            print("Unable to find the beep sound file.")
        }
    }

    
    func captureSession(_ session: RoomCaptureSession, didUpdate room: CapturedRoom) {
        if let depthMap = session.arSession.currentFrame?.sceneDepth?.depthMap {
            // Access the depth map's pixel buffer.
            CVPixelBufferLockBaseAddress(depthMap, .readOnly)
            let width = CVPixelBufferGetWidth(depthMap)
            let height = CVPixelBufferGetHeight(depthMap)
            
            // Assuming you want the depth at a specific point (e.g., center of the depth map).
            let x = width / 2
            let y = height / 2
            
            // Access the data
//            if let baseAddress = CVPixelBufferGetBaseAddress(depthMap) {
//                let floatBuffer = baseAddress.assumingMemoryBound(to: Float.self)
//                
//                // Calculate the index for the desired pixel
//                let index = x + y * width
//                
//                // Get the distance as a float
//                let distance = floatBuffer[index]
//                
//                while distance < 0.3 && distance >= 0.2 {
//                    let feedbackGenerator = UIImpactFeedbackGenerator(style: .light)
//                    feedbackGenerator.prepare()
//                    feedbackGenerator.impactOccurred()
//                    
//                }
//                
//                while distance < 0.2 && distance >= 0.1 {
//                    let feedbackGenerator = UIImpactFeedbackGenerator(style: .medium)
//                    feedbackGenerator.prepare()
//                    feedbackGenerator.impactOccurred()
//                }
//                
//                
//                
//                while distance < 0.1 {
//                    let feedbackGenerator = UIImpactFeedbackGenerator(style: .heavy)
//                    feedbackGenerator.prepare()
//                    feedbackGenerator.impactOccurred()
//                }
//                
//                // Use the distance variable as needed
//                print("Distance at (\(x), \(y)): \(distance) meters")
//            }
            
            if let baseAddress = CVPixelBufferGetBaseAddress(depthMap) {
                let floatBuffer = baseAddress.assumingMemoryBound(to: Float.self)
                let index = x + y * width
                let distance = floatBuffer[index]

                DispatchQueue.main.async {
                    self.distance = Double(distance);
                    self.setInterval()
                }
            }
            
            CVPixelBufferUnlockBaseAddress(depthMap, .readOnly)
        }
    }
    
    // Function to update the interval
    func setInterval() {
        // Calculate beep rate based on the distance
        if distance < 5.0 {
            // As distance decreases, the soundInterval decreases (sound plays more frequently)
            self.soundInterval = max(0.5, distance) // Ensures a minimum interval for sound
            
        let hapticInterval = self.distance / 30
        self.interval = hapticInterval


        } else {
            // Disable beep sound if distance is 5 or more
            self.soundInterval = Double.greatestFiniteMagnitude
        }

        updateTimer()
    }


    
    
    @objc private func triggerHapticFeedback() {
        let feedbackGenerator: UIImpactFeedbackGenerator
        switch self.distance {
        case 3...5:
            feedbackGenerator = UIImpactFeedbackGenerator(style: .light)
        case 2...3:
            feedbackGenerator = UIImpactFeedbackGenerator(style: .medium)
        case ..<2:
            feedbackGenerator = UIImpactFeedbackGenerator(style: .heavy)
        default:
            return
        }
        feedbackGenerator.prepare()
        feedbackGenerator.impactOccurred()

        // Increment and check the counter
        hapticFeedbackCount += 1
        if hapticFeedbackCount >= 5 {
            playBeepSound()
            hapticFeedbackCount = 0
        }
    }

    
    @objc private func playBeepSound() {
        if distance < 5.0 {
            audioPlayer?.play()
        }
    }

    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        startSession()
    }
    
    override func viewWillDisappear(_ flag: Bool) {
        super.viewWillDisappear(flag)
        stopSession()
    }
    
    private func startSession() {
        isScanning = true
        roomCaptureView?.captureSession.run(configuration: roomCaptureSessionConfig)
        
        setActiveNavBar()
    }
    
    private func stopSession() {
        isScanning = false
        roomCaptureView?.captureSession.stop()

        // Invalidate beep timer and stop beep sound
        beepTimer?.invalidate()
        audioPlayer?.stop()

        setCompleteNavBar()
    }
    
    // Decide to post-process and show the final results.
    func captureView(shouldPresent roomDataForProcessing: CapturedRoomData, error: Error?) -> Bool {
        return true
    }
    
    // Access the final post-processed results.
    func captureView(didPresent processedResult: CapturedRoom, error: Error?) {
        finalResults = processedResult
        self.exportButton?.isEnabled = true
        self.activityIndicator?.stopAnimating()
    }
    
    @IBAction func doneScanning(_ sender: UIBarButtonItem) {
        if isScanning {
            stopSession()
            stopHapticFeedbackTimer() // Add this line to stop the timer
        } else {
            cancelScanning(sender)
        }
        self.exportButton?.isEnabled = false
        self.activityIndicator?.startAnimating()
    }
    
    private func stopHapticFeedbackTimer() {
        timer?.invalidate()
        timer = nil // Optionally set the timer to nil
    }
        
    @IBAction func cancelScanning(_ sender: UIBarButtonItem) {
        navigationController?.dismiss(animated: true)
    }
    
    // Export the USDZ output by specifying the `.parametric` export option.
    // Alternatively, `.mesh` exports a nonparametric file and `.all`
    // exports both in a single USDZ.
    @IBAction func exportResults(_ sender: UIButton) {
        let destinationFolderURL = FileManager.default.temporaryDirectory.appending(path: "Export")
        let destinationURL = destinationFolderURL.appending(path: "Room.usdz")
        let capturedRoomURL = destinationFolderURL.appending(path: "Room.json")
        do {
            try FileManager.default.createDirectory(at: destinationFolderURL, withIntermediateDirectories: true)
            let jsonEncoder = JSONEncoder()
            let jsonData = try jsonEncoder.encode(finalResults)
            try jsonData.write(to: capturedRoomURL)
            try finalResults?.export(to: destinationURL, exportOptions: .parametric)
            
            let activityVC = UIActivityViewController(activityItems: [destinationFolderURL], applicationActivities: nil)
            activityVC.modalPresentationStyle = .popover
            
            present(activityVC, animated: true, completion: nil)
            if let popOver = activityVC.popoverPresentationController {
                popOver.sourceView = self.exportButton
            }
        } catch {
            print("Error = \(error)")
        }
    }
    
    private func setActiveNavBar() {
        UIView.animate(withDuration: 1.0, animations: {
            self.cancelButton?.tintColor = .white
            self.doneButton?.tintColor = .white
            self.exportButton?.alpha = 0.0
        }, completion: { complete in
            self.exportButton?.isHidden = true
        })
    }
    
    private func setCompleteNavBar() {
        self.exportButton?.isHidden = false
        UIView.animate(withDuration: 1.0) {
            self.cancelButton?.tintColor = .systemBlue
            self.doneButton?.tintColor = .systemBlue
            self.exportButton?.alpha = 1.0
        }
    }
    
    // Don't forget to invalidate the timer when the view controller is deinitialized
    deinit {
        timer?.invalidate()
        beepTimer?.invalidate()
        audioPlayer?.stop()
    }
}
