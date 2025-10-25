package com.lockloom.dpc

import android.content.Intent
import android.net.Uri
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.core.content.edit

class BounceActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val prefs = getSharedPreferences("ll_bootstrap", MODE_PRIVATE)
        val alreadyBounced = prefs.getBoolean("bounced", false)

        if (!alreadyBounced) {
            val pkg = "com.lockloom.android"
            val playIntent = Intent(Intent.ACTION_VIEW,
                Uri.parse("market://details?id=$pkg")
            ).addFlags(
                Intent.FLAG_ACTIVITY_NEW_TASK or
                Intent.FLAG_ACTIVITY_CLEAR_TOP or
                Intent.FLAG_ACTIVITY_SINGLE_TOP
            )
            val webFallback = Intent(Intent.ACTION_VIEW,
                Uri.parse("https://play.google.com/store/apps/details?id=$pkg")
            )
            try { startActivity(playIntent) } catch (_: Exception) { startActivity(webFallback) }
            prefs.edit { putBoolean("bounced", true) }
        }

        finish()
    }
}
