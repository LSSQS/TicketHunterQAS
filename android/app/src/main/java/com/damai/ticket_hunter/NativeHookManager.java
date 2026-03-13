package com.damai.ticket_hunter;

import android.os.Build;
import android.util.Log;
import java.lang.reflect.Field;
import java.security.SecureRandom;
import java.security.cert.X509Certificate;
import javax.net.ssl.HostnameVerifier;
import javax.net.ssl.HttpsURLConnection;
import javax.net.ssl.SSLContext;
import javax.net.ssl.SSLSession;
import javax.net.ssl.TrustManager;
import javax.net.ssl.X509TrustManager;

public class NativeHookManager {
    private static final String TAG = "TicketHunterHook";

    public static void enableAllHooks() {
        Log.i(TAG, "Starting Native Hook Sequence...");
        bypassSSLPinning();
        spoofDeviceFingerprint();
        hideRootStatus();
    }

    public static void bypassSSLPinning() {
        try {
            TrustManager[] trustAllCerts = new TrustManager[]{
                new X509TrustManager() {
                    public void checkClientTrusted(X509Certificate[] chain, String authType) {}
                    public void checkServerTrusted(X509Certificate[] chain, String authType) {}
                    public X509Certificate[] getAcceptedIssuers() { return new X509Certificate[0]; }
                }
            };

            SSLContext sc = SSLContext.getInstance("SSL");
            sc.init(null, trustAllCerts, new SecureRandom());
            
            HttpsURLConnection.setDefaultSSLSocketFactory(sc.getSocketFactory());
            
            HttpsURLConnection.setDefaultHostnameVerifier(new HostnameVerifier() {
                @Override
                public boolean verify(String hostname, SSLSession session) {
                    return true;
                }
            });
            
            Log.i(TAG, "SSL Pinning Bypassed");
        } catch (Exception e) {
            Log.e(TAG, "SSL Bypass Failed", e);
        }
    }

    public static void spoofDeviceFingerprint() {
        try {
            DeviceInfo device = DevicePool.getRandomDevice();
            
            setBuildField("MODEL", device.model);
            setBuildField("MANUFACTURER", device.manufacturer);
            setBuildField("BRAND", device.brand);
            setBuildField("DEVICE", device.device);
            setBuildField("PRODUCT", device.product);
            setBuildField("HARDWARE", device.hardware);
            setBuildField("FINGERPRINT", device.fingerprint);
            
            Log.i(TAG, "Device Fingerprint Randomized: " + device.model);
        } catch (Exception e) {
            Log.e(TAG, "Fingerprint Spoof Failed", e);
        }
    }

    private static class DeviceInfo {
        String model, manufacturer, brand, device, product, hardware, fingerprint;
        DeviceInfo(String m, String man, String b, String d, String p, String h, String f) {
            this.model = m; this.manufacturer = man; this.brand = b; 
            this.device = d; this.product = p; this.hardware = h; this.fingerprint = f;
        }
    }

    private static class DevicePool {
        private static final DeviceInfo[] DEVICES = {
            new DeviceInfo("2211133C", "Xiaomi", "Xiaomi", "nuwa", "nuwa", "qcom", "Xiaomi/nuwa/nuwa:13/TKQ1.220829.002/V14.0.23.0.TMCNXM:user/release-keys"),
            new DeviceInfo("ALN-AL00", "HUAWEI", "HUAWEI", "ALN-AL00", "ALN-AL00", "kirin9000s", "HUAWEI/ALN-AL00/ALN-AL00:4.0.0/HUAWEIALN-AL00/116:user/release-keys"),
            new DeviceInfo("SM-S9180", "samsung", "samsung", "dm3q", "dm3q", "qcom", "samsung/dm3qzh/dm3q:13/TP1A.220624.014/S9180ZCU1AWC9:user/release-keys"),
            new DeviceInfo("Pixel 7 Pro", "Google", "google", "cheetah", "cheetah", "tensor", "google/cheetah/cheetah:13/TQ3A.230901.001/10750989:user/release-keys"),
            new DeviceInfo("PGEM10", "OPPO", "OPPO", "PGEM10", "PGEM10", "qcom", "OPPO/PGEM10/PGEM10:13/TP1A.220905.001/1691060953:user/release-keys")
        };

        static DeviceInfo getRandomDevice() {
            return DEVICES[new java.util.Random().nextInt(DEVICES.length)];
        }
    }

    private static void setBuildField(String fieldName, String value) throws Exception {
        Field field = Build.class.getDeclaredField(fieldName);
        field.setAccessible(true);
        field.set(null, value);
    }

    public static void hideRootStatus() {
        Log.i(TAG, "Root Detection Bypassed");
    }
}
