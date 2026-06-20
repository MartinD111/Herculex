package com.ams.herculex

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import com.google.android.gms.wearable.PutDataMapRequest
import com.google.android.gms.wearable.Wearable
import android.util.Log

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.herculex/wear"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "syncMacros") {
                val calories = call.argument<Int>("calories") ?: 0
                val protein = call.argument<Int>("protein") ?: 0
                syncToWear(calories, protein)
                result.success(null)
            } else {
                result.notImplemented()
            }
        }
    }

    private fun syncToWear(calories: Int, protein: Int) {
        val putDataMapReq = PutDataMapRequest.create("/swy_sync_data")
        putDataMapReq.dataMap.putInt("calories", calories)
        putDataMapReq.dataMap.putInt("protein", protein)
        putDataMapReq.dataMap.putLong("timestamp", System.currentTimeMillis())
        val putDataReq = putDataMapReq.asPutDataRequest()
        putDataReq.setUrgent()
        Wearable.getDataClient(this).putDataItem(putDataReq)
            .addOnSuccessListener {
                Log.d("WearSync", "Successfully synced macros to wear: $calories kcal, $protein g")
            }
            .addOnFailureListener { e ->
                Log.e("WearSync", "Failed to sync macros to wear", e)
            }
    }
}
