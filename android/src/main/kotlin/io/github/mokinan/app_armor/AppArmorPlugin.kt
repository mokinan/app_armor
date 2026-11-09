package io.github.mokinan.app_armor

import android.app.Activity
import android.content.Context
import android.os.Build
import android.view.WindowManager
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/** Screen privacy for AppArmor: FLAG_SECURE, recents, tapjacking, screenshots. */
class AppArmorPlugin : FlutterPlugin, ActivityAware, MethodChannel.MethodCallHandler {
    private lateinit var channel: MethodChannel
    private lateinit var context: Context
    private var activity: Activity? = null

    private var hideInAppSwitcher = false
    private var blockScreenshots = false
    private var secureScreen = false
    private var preventTapjacking = false
    private var detectScreenshots = false

    private var screenCaptureCallback: Any? = null

    /** Nothing is changed on the window until Dart has sent the config. */
    private var configured = false

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, "app_armor")
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "configure" -> {
                hideInAppSwitcher = call.argument<Boolean>("hideInAppSwitcher") ?: false
                blockScreenshots = call.argument<Boolean>("blockScreenshots") ?: false
                preventTapjacking = call.argument<Boolean>("preventTapjacking") ?: false
                detectScreenshots = call.argument<Boolean>("detectScreenshots") ?: false
                configured = true
                apply()
                result.success(null)
            }
            "setSecureScreen" -> {
                secureScreen = call.arguments as? Boolean ?: false
                configured = true
                apply()
                result.success(null)
            }
            "isScreenCaptured" -> result.success(false)
            "consumeFirstRun" -> result.success(consumeFirstRun())
            else -> result.notImplemented()
        }
    }

    /** True once per install: the flag lives in the app's own storage. */
    private fun consumeFirstRun(): Boolean {
        val prefs = context.getSharedPreferences("app_armor", Context.MODE_PRIVATE)
        if (prefs.getBoolean("installed", false)) return false
        prefs.edit().putBoolean("installed", true).apply()
        return true
    }

    private fun apply() {
        val activity = activity ?: return
        if (!configured) return
        val window = activity.window

        if (blockScreenshots || secureScreen) {
            window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
        } else {
            window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
        }

        // Android 13+: blank card in recent apps; screenshots stay allowed.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            activity.setRecentsScreenshotEnabled(!hideInAppSwitcher)
        }

        // Drops touches that pass through another app's overlay.
        window.decorView.filterTouchesWhenObscured = preventTapjacking

        if (detectScreenshots) registerScreenCapture(activity) else unregisterScreenCapture(activity)
    }

    private fun registerScreenCapture(activity: Activity) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.UPSIDE_DOWN_CAKE) return
        if (screenCaptureCallback != null) return
        val callback = Activity.ScreenCaptureCallback {
            channel.invokeMethod("screenshotTaken", null)
        }
        try {
            activity.registerScreenCaptureCallback(activity.mainExecutor, callback)
            screenCaptureCallback = callback
        } catch (e: SecurityException) {
            // DETECT_SCREEN_CAPTURE removed from the manifest: skip detection.
        }
    }

    private fun unregisterScreenCapture(activity: Activity) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.UPSIDE_DOWN_CAKE) return
        val callback = screenCaptureCallback as? Activity.ScreenCaptureCallback ?: return
        try {
            activity.unregisterScreenCaptureCallback(callback)
        } catch (e: Exception) {
        }
        screenCaptureCallback = null
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
        apply()
    }

    override fun onDetachedFromActivityForConfigChanges() = detach()

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) =
        onAttachedToActivity(binding)

    override fun onDetachedFromActivity() = detach()

    private fun detach() {
        activity?.let { unregisterScreenCapture(it) }
        activity = null
    }
}
