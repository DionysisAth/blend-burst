package com.nwbn.blendburst

import android.util.Log
import com.google.android.gms.common.ConnectionResult
import com.google.android.gms.common.GoogleApiAvailability
import com.google.android.gms.games.PlayGamesSdk
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "blend_burst/games")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "init" -> result.success(initPlayGames())
                    else -> result.notImplemented()
                }
            }
    }

    /**
     * Starts Play Games only when a real project ID is set in
     * res/values/games.xml and Google Play services is on the device.
     * Otherwise Play Games is never touched, so a build without it set up
     * cannot crash because of it.
     */
    private fun initPlayGames(): Boolean {
        if (playGamesReady) return true
        return try {
            val id = getString(R.string.game_services_project_id).trim()
            if (!id.matches(Regex("\\d{6,}"))) return false
            val gms = GoogleApiAvailability.getInstance()
                .isGooglePlayServicesAvailable(applicationContext)
            if (gms != ConnectionResult.SUCCESS) return false
            PlayGamesSdk.initialize(applicationContext)
            playGamesReady = true
            true
        } catch (e: Throwable) {
            Log.w("BlendBurst", "Play Games unavailable", e)
            false
        }
    }

    companion object {
        private var playGamesReady = false
    }
}
