<?php
// Configuration
$android_package = 'com.el_race.app';
$ios_bundle_id = 'com.elrace.app'; 
$android_fallback = "https://play.google.com/store/apps/details?id=$android_package";
$ios_fallback = 'https://apps.apple.com/us/app/el-race-cont-operations/id6748855825';

$deep_link = "https://elrace.com/RCC4/Requirements/qrcodeapp";

$userAgent = $_SERVER['HTTP_USER_AGENT'] ?? '';
$isAndroid = stripos($userAgent, 'Android') !== false;
$isIOS = stripos($userAgent, 'iPhone') !== false || stripos($userAgent, 'iPad') !== false || stripos($userAgent, 'iPod') !== false;
?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>El Race - QR Survey</title>
    
    <meta name="apple-itunes-app" content="app-id=6748855825, app-argument=<?php echo $deep_link; ?>">
    
    <meta name="google-play-app" content="app-id=<?php echo $android_package; ?>">
    
    <style>
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, Cantarell, sans-serif;
            display: flex;
            flex-direction: column;
            align-items: center;
            justify-content: center;
            min-height: 100vh;
            margin: 0;
            padding: 20px;
            background: linear-gradient(135deg, #1E3A5F 0%, #2980b9 100%);
            color: white;
            text-align: center;
        }
        .container {
            max-width: 400px;
            background: rgba(255, 255, 255, 0.1);
            padding: 30px;
            border-radius: 15px;
            backdrop-filter: blur(10px);
            box-shadow: 0 8px 32px rgba(0, 0, 0, 0.3);
        }
        h1 {
            font-size: 24px;
            margin-bottom: 20px;
        }
        .spinner {
            border: 4px solid rgba(255, 255, 255, 0.3);
            border-radius: 50%;
            border-top: 4px solid white;
            width: 50px;
            height: 50px;
            animation: spin 1s linear infinite;
            margin: 20px auto;
        }
        @keyframes spin {
            0% { transform: rotate(0deg); }
            100% { transform: rotate(360deg); }
        }
        .btn {
            display: inline-block;
            margin: 10px;
            padding: 12px 30px;
            background: white;
            color: #1E3A5F;
            text-decoration: none;
            border-radius: 25px;
            font-weight: bold;
            transition: transform 0.2s;
        }
        .btn:hover {
            transform: scale(1.05);
        }
        .message {
            margin: 20px 0;
            line-height: 1.6;
        }
    </style>
    
    <script>
        function isAndroid() {
            return /Android/i.test(navigator.userAgent);
        }
        
        function isIOS() {
            return /iPhone|iPad|iPod/i.test(navigator.userAgent);
        }
        
        function isMobile() {
            return isAndroid() || isIOS();
        }
        
        function openApp() {
            var deepLink = "<?php echo $deep_link; ?>";
            var androidFallback = "<?php echo $android_fallback; ?>";
            var iosFallback = "<?php echo $ios_fallback; ?>";
            var redirected = false;
            var fallbackTimer = null;

            function markRedirected() {
                redirected = true;
                if (fallbackTimer) {
                    clearTimeout(fallbackTimer);
                    fallbackTimer = null;
                }
            }

            // If app opens, browser usually gets hidden/backgrounded.
            document.addEventListener('visibilitychange', function() {
                if (document.hidden) markRedirected();
            });
            window.addEventListener('pagehide', markRedirected);
            window.addEventListener('blur', markRedirected);
            
            if (isAndroid()) {
                console.log('Android detected - attempting to open app');
                
                window.location.href = deepLink;
                
                fallbackTimer = setTimeout(function() {
                    if (redirected || document.hidden) return;
                    console.log('Fallback to Play Store');
                    window.location.href = androidFallback;
                }, 1800);
                
            } else if (isIOS()) {
                console.log('iOS detected - attempting to open app');
                
                // Try Universal Links first
                window.location.href = deepLink;
                
                // Fallback to App Store after 2.5 seconds if app doesn't open
                fallbackTimer = setTimeout(function() {
                    if (redirected || document.hidden) return;
                    console.log('Fallback to App Store');
                    window.location.href = iosFallback;
                }, 1800);
                
            } else {
                document.getElementById('loading').style.display = 'none';
                document.getElementById('desktop-message').style.display = 'block';
            }
        }
        
        window.onload = function() {
            if (isMobile()) {
                openApp();
            } else {
                document.getElementById('loading').style.display = 'none';
                document.getElementById('desktop-message').style.display = 'block';
            }
        };
    </script>
</head>
<body>
    <div class="container">
        <div id="loading" style="display: block;">
            <h1>Opening El Race App...</h1>
            <div class="spinner"></div>
            <p class="message">Please wait while we redirect you to the app.</p>
            <p style="font-size: 14px; opacity: 0.8;">If the app doesn't open automatically, you'll be redirected to download it.</p>
        </div>
        
        <div id="desktop-message" style="display: none;">
            <h1>📱 El Race QR Survey</h1>
            <p class="message">
                This link is designed for mobile devices.<br>
                Please scan the QR code with your mobile device to continue.
            </p>
            <div style="margin-top: 30px;">
                <p style="font-size: 14px; opacity: 0.9;">Download the app:</p>
                <?php if ($isAndroid): ?>
                    <a href="<?php echo $android_fallback; ?>" class="btn">Download for Android</a>
                <?php elseif ($isIOS): ?>
                    <a href="<?php echo $ios_fallback; ?>" class="btn">Download for iOS</a>
                <?php else: ?>
                    <a href="<?php echo $android_fallback; ?>" class="btn">Android</a>
                    <a href="<?php echo $ios_fallback; ?>" class="btn">iOS</a>
                <?php endif; ?>
            </div>
        </div>
    </div>
    
    <!-- Debug info (remove in production) -->
    <?php if (isset($_GET['debug'])): ?>
    <div style="position: fixed; bottom: 10px; left: 10px; right: 10px; background: rgba(0,0,0,0.8); color: #0f0; padding: 10px; font-size: 10px; font-family: monospace; border-radius: 5px;">
        <strong>Debug Info:</strong><br>
        User Agent: <?php echo htmlspecialchars($userAgent); ?><br>
        Is Android: <?php echo $isAndroid ? 'Yes' : 'No'; ?><br>
        Is iOS: <?php echo $isIOS ? 'Yes' : 'No'; ?><br>
        Deep Link: <?php echo $deep_link; ?><br>
        Android Package: <?php echo $android_package; ?><br>
        iOS Bundle ID: <?php echo $ios_bundle_id; ?>
    </div>
    <?php endif; ?>
</body>
</html>
