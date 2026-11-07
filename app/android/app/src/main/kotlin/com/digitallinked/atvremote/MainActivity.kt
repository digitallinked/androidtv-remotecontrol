package com.digitallinked.atvremote

import android.content.Context
import android.telephony.TelephonyManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.digitallinked.atvremote/region",
        ).setMethodCallHandler { call, result ->
            if (call.method == "phoneCountry") {
                result.success(phoneCountry())
            } else {
                result.notImplemented()
            }
        }
    }

    // The SIM's country, then the network's, for the default app row: the language list doesn't
    // say where a phone is (a phone in Malaysia set to British English reports en-GB). Neither
    // call needs a permission, and both are empty on a device with no SIM.
    private fun phoneCountry(): String? {
        val telephony = getSystemService(Context.TELEPHONY_SERVICE) as? TelephonyManager
        return listOf(telephony?.simCountryIso, telephony?.networkCountryIso)
            .firstOrNull { !it.isNullOrBlank() }
    }
}
