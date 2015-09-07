package com.opteam.virtualight;

import android.app.Activity;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.graphics.Bitmap;
import android.graphics.Color;
import android.graphics.PixelFormat;
import android.graphics.SurfaceTexture;
import android.graphics.drawable.BitmapDrawable;
import android.hardware.Camera;
import android.hardware.Sensor;
import android.hardware.SensorEvent;
import android.hardware.SensorEventListener;
import android.hardware.SensorManager;
import android.location.Location;
import android.location.LocationListener;
import android.location.LocationManager;
import android.os.Bundle;
import android.util.Log;
import android.view.Menu;
import android.view.MenuItem;
import android.view.TextureView;
import android.view.View;
import android.widget.ImageView;
import android.widget.RelativeLayout;
import android.widget.TextView;

import com.getpebble.android.kit.PebbleKit;
import com.getpebble.android.kit.util.PebbleDictionary;

import java.io.IOException;
import java.util.ArrayList;
import java.util.UUID;

@SuppressWarnings("deprecation")
public class MainActivity extends Activity implements TextureView.SurfaceTextureListener, SensorEventListener{
    private static final String TAG = "MAINACTIVITY";

    private static final UUID PEBBLE_UUID = UUID.fromString("03c9f6cc-e9e4-4697-893f-90ecc16aa768");

    private Camera mCamera;
    private boolean isOpen = false;

    private int padding = -1;
    private int sidePadding = -1;

    private TextureView leftView;
    private ImageView rightView;

    private TextView statusViewLeft;
    private TextView statusViewRight;

    private TextView activityViewLeft;
    private TextView activityViewRight;

    private TextView compassViewLeft;
    private TextView compassViewRight;
    private SensorManager mSensorManager;
    private Sensor mAccelerometer;
    private float[] mGravity;
    private Sensor mMagnetometer;
    private float[] mGeomagnetic;

    private PebbleKit.PebbleDataReceiver pebbleDataReceiver;
    private final int TESTKEY = 5;
    private final int ACCELKEY = 25;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_main);
        getWindow().setFormat(PixelFormat.UNKNOWN);
        getWindow().getDecorView().setSystemUiVisibility(View.SYSTEM_UI_FLAG_FULLSCREEN |
                View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN);

        leftView = (TextureView) findViewById(R.id.camera_preview_left);
        rightView = (ImageView) findViewById(R.id.camera_preview_right);

        leftView.setSurfaceTextureListener(this);

        statusViewLeft = (TextView) findViewById(R.id.status_view_left);
        statusViewRight = (TextView) findViewById(R.id.status_view_right);
        updateStatusViews();

        pebbleDataReceiver = new PebbleKit.PebbleDataReceiver(PEBBLE_UUID) {
            @Override
            public void receiveData(Context context, int transactionId, PebbleDictionary data) {
                try {
                    long testData = data.getInteger(TESTKEY);
                    Log.d(TAG, Long.toString(testData));
                } catch (NullPointerException e) {

                }
                try {
                    String accelData = data.getString(ACCELKEY);
                    String[] splitData = accelData.split(",");
                    AccelData sample = new AccelData(splitData);
                    performAnalyses(sample);
                } catch (NullPointerException e) {

                }

                PebbleKit.sendAckToPebble(getApplicationContext(), transactionId);
            }
        };

        activityViewLeft = (TextView) findViewById(R.id.activity_view_left);
        activityViewRight = (TextView) findViewById(R.id.activity_view_right);
        LocationManager locationManager = (LocationManager) getSystemService(LOCATION_SERVICE);
        LocationListener locationListener = new LocationListener() {
            public void onLocationChanged(Location location) {

            }

            public void onStatusChanged(String provider, int status, Bundle extras) {}

            public void onProviderEnabled(String provider) {}

            public void onProviderDisabled(String provider) {}
        };
        locationManager.requestLocationUpdates(LocationManager.GPS_PROVIDER, 0, 0, locationListener);
//        updateSpeedViews(locationManager.getLastKnownLocation(LocationManager.GPS_PROVIDER));

        compassViewLeft = (TextView) findViewById(R.id.compass_view_left);
        compassViewRight = (TextView) findViewById(R.id.compass_view_right);
        mSensorManager = (SensorManager) getSystemService(SENSOR_SERVICE);
        if (mSensorManager.getDefaultSensor(Sensor.TYPE_MAGNETIC_FIELD) != null) {
            mMagnetometer = mSensorManager.getDefaultSensor(Sensor.TYPE_MAGNETIC_FIELD);
        }
        if (mSensorManager.getDefaultSensor(Sensor.TYPE_ACCELEROMETER) != null) {
            mAccelerometer = mSensorManager.getDefaultSensor(Sensor.TYPE_ACCELEROMETER);
        }
    }

    @Override
    protected void onResume() {
        super.onResume();

        BroadcastReceiver statusReceiver = new BroadcastReceiver() {

            @Override
            public void onReceive(Context context, Intent intent) {
                updateStatusViews();
            }

        };

        PebbleKit.registerPebbleConnectedReceiver(getApplicationContext(), statusReceiver);
        PebbleKit.registerPebbleDisconnectedReceiver(getApplicationContext(), statusReceiver);
        PebbleKit.startAppOnPebble(getApplicationContext(), PEBBLE_UUID);

        PebbleKit.registerReceivedDataHandler(this, pebbleDataReceiver);

        mSensorManager = (SensorManager) getSystemService(SENSOR_SERVICE);
        mSensorManager.registerListener(this, mAccelerometer, SensorManager.SENSOR_DELAY_UI);
        mSensorManager.registerListener(this, mMagnetometer, SensorManager.SENSOR_DELAY_UI);
    }

    @Override
    protected void onPause() {
        super.onPause();

        if (padding >= 0) {
            RelativeLayout mainLayout = (RelativeLayout) findViewById(R.id.main_activity_layout);
            mainLayout.setPadding(sidePadding, padding, sidePadding, padding);
        }

        PebbleKit.closeAppOnPebble(getApplicationContext(), PEBBLE_UUID);

        PebbleKit.registerPebbleConnectedReceiver(getApplicationContext(), null);
        PebbleKit.registerPebbleDisconnectedReceiver(getApplicationContext(), null);
        unregisterReceiver(pebbleDataReceiver);

        mSensorManager.unregisterListener(this, mAccelerometer);
        mSensorManager.unregisterListener(this, mMagnetometer);
    }

    private final int LIMIT = 20;
    ArrayList<AccelData> dataArrayList = new ArrayList<>();

    private void performAnalyses(AccelData data) {
        if (dataArrayList.size() < LIMIT) {
            dataArrayList.add(data);
        } else {
            double xMean = 0;
            double yMean = 0;
            double zMean = 0;
            for (AccelData datum : dataArrayList) {
                xMean += datum.getxAcceleration();
                yMean += datum.getyAcceleration();
                zMean += datum.getzAcceleration();
            }
            xMean /= LIMIT;
            yMean /= LIMIT;
            zMean /= LIMIT;
            double xStandardDeviation = 0;
            double yStandardDeviation = 0;
            double zStandardDeviation = 0;
            for (AccelData datum : dataArrayList) {
                xStandardDeviation += Math.pow(datum.getxAcceleration() - xMean, 2);
                yStandardDeviation += Math.pow(datum.getyAcceleration() - yMean, 2);
                zStandardDeviation += Math.pow(datum.getzAcceleration() - zMean, 2);
            }
            xStandardDeviation /= LIMIT;
            yStandardDeviation /= LIMIT;
            zStandardDeviation /= LIMIT;
            xStandardDeviation = Math.sqrt(xStandardDeviation);
            yStandardDeviation = Math.sqrt(yStandardDeviation);
            zStandardDeviation = Math.sqrt(zStandardDeviation);
            double xRatio = Math.abs(xStandardDeviation / xMean);
            double yRatio = Math.abs(yStandardDeviation / yMean);
            double zRatio = Math.abs(zStandardDeviation / zMean);
            String summaryString = Double.toString(xRatio) + " " + Double.toString(yRatio) + " " + Double.toString(zRatio);
            Log.d(TAG, summaryString);

            if (xRatio < 0.15 && yRatio < 0.2) {
                updateActivityViews("standing");
            } else if (xRatio < 0.35 && yRatio < 0.5) {
                updateActivityViews("walking");
            } else if (xRatio < 0.5 && yRatio < 1.5) {
                updateActivityViews("speed-walking");
            } else if (xRatio < 2 && yRatio < 3) {
                updateActivityViews("jogging");
            } else {
                updateActivityViews("moving");
            }

            dataArrayList.clear();
        }
    }

    private void updateStatusViews() {
        boolean connected = PebbleKit.isWatchConnected(getApplicationContext());
        String message = "Status: " + (connected ? "Connected" : "Not connected");
        int color = (connected ? getResources().getColor(R.color.text_blue) :
            getResources().getColor(R.color.text_red));
        statusViewLeft.setText(message);
        statusViewRight.setText(message);
        statusViewLeft.setTextColor(color);
        statusViewRight.setTextColor(color);
    }

    private void updateActivityViews(String status) {
        activityViewLeft.setText("You are " + status);
        activityViewRight.setText("You are " + status);
    }

    @Override
    public void onSensorChanged(SensorEvent event) {
        if (event.sensor.getType() == Sensor.TYPE_ACCELEROMETER)
            mGravity = event.values;
        if (event.sensor.getType() == Sensor.TYPE_MAGNETIC_FIELD)
            mGeomagnetic = event.values;
        if (mGravity != null && mGeomagnetic != null) {
            float R[] = new float[9];
            float I[] = new float[9];
            boolean success = SensorManager.getRotationMatrix(R, I, mGravity,
                    mGeomagnetic);
            if (success) {
                float orientation[] = new float[3];
                SensorManager.getOrientation(R, orientation);
                for (int idx = 0; idx < orientation.length; idx++) {
                    orientation[idx] = (float) Math.toDegrees(orientation[idx]);
                }
//                Log.d(TAG, Float.toString(orientation[0]) + " "  + Float.toString(orientation[1]) + " "  + Float.toString(orientation[2]));
                if (orientation[2] > -94 && orientation[2] < -86) {
                    compassViewLeft.setText(getDirection(orientation[0]));
                    compassViewRight.setText(getDirection(orientation[0]));
                    if (compassViewLeft.getText().equals("N")) {
                        compassViewLeft.setTextColor(getResources()
                                .getColor(com.opteam.virtualight.R.color.text_red));
                        compassViewRight.setTextColor(getResources()
                                .getColor(com.opteam.virtualight.R.color.text_red));
                    } else {
                        compassViewLeft.setTextColor(Color.WHITE);
                        compassViewRight.setTextColor(Color.WHITE);
                    }
                } else {
                    compassViewLeft.setText("");
                    compassViewRight.setText("");
                }
            }
        }
    }

    @Override
    public void onAccuracyChanged(Sensor sensor, int accuracy) {

    }

    private String getDirection(float azimuthDegree) {
        if (azimuthDegree > 157.5 || azimuthDegree < -157.5)
            return "S";
        else if (azimuthDegree > 112.5)
            return "SW";
        else if (azimuthDegree > 67.5)
            return "W";
        else if (azimuthDegree > 22.5)
            return "NW";
        else if (azimuthDegree > -22.5)
            return "N";
        else if (azimuthDegree > -67.5)
            return "NE";
        else if (azimuthDegree > -112.5)
            return "E";
        else
            return "SE";
    }

    @Override
    public void onSurfaceTextureAvailable(SurfaceTexture surface, int width, int height) {
        if (!isOpen) {
            mCamera = Camera.open();
        }

        try {
            if (mCamera == null) {
                return;
            }

            Camera.Parameters parameters = mCamera.getParameters();
            parameters.setFocusMode(Camera.Parameters.FOCUS_MODE_AUTO);
            int[] bestFps = parameters.getSupportedPreviewFpsRange().get(1);
            parameters.setPreviewFpsRange(bestFps[0], bestFps[1]);

            int sidePadding = 100;
            int oldWidth = leftView.getWidth();
            int newWidth = oldWidth - sidePadding;
            int oldHeight = leftView.getHeight();
            // 1440 width, 1080 height
            Camera.Size bestSize = parameters.getSupportedPreviewSizes().get(1);
            int newHeight = (int) (newWidth * (bestSize.height * 1.0) / bestSize.width);
            int padding = (oldHeight - newHeight) / 2;

            RelativeLayout mainLayout = (RelativeLayout) findViewById(R.id.main_activity_layout);
            mainLayout.setPadding(sidePadding, padding, sidePadding, padding);

            this.padding = padding;
            this.sidePadding = sidePadding;

            parameters.setPreviewSize(bestSize.width, bestSize.height);

            mCamera.setParameters(parameters);

            mCamera.setPreviewTexture(surface);
            mCamera.startPreview();
        } catch (IOException e) {
            // Something bad happened
            e.printStackTrace();
        }
    }

    @Override
    public void onSurfaceTextureSizeChanged(SurfaceTexture surface, int width, int height) {
        // Ignored, Camera does all the work for us
        try {
            mCamera.setPreviewTexture(surface);
        } catch (IOException e) {
            e.printStackTrace();
        }
    }

    @Override
    public boolean onSurfaceTextureDestroyed(SurfaceTexture surface) {
        mCamera.stopPreview();
        mCamera.release();
        isOpen = false;
        return true;
    }

    @Override
    public void onSurfaceTextureUpdated(SurfaceTexture surface) {
        // Invoked every time there's a new Camera preview frame
        Bitmap image = leftView.getBitmap();
        BitmapDrawable bitmapDrawable = new BitmapDrawable(getResources(), image);
        rightView.setImageDrawable(bitmapDrawable);
    }

    @Override
    public boolean onCreateOptionsMenu(Menu menu) {
        // Inflate the menu; this adds items to the action bar if it is present.
        getMenuInflater().inflate(R.menu.menu_main, menu);
        return true;
    }

    @Override
    public boolean onOptionsItemSelected(MenuItem item) {
        // Handle action bar item clicks here. The action bar will
        // automatically handle clicks on the Home/Up button, so long
        // as you specify a parent activity in AndroidManifest.xml.
        int id = item.getItemId();

        //noinspection SimplifiableIfStatement
        if (id == R.id.action_settings) {
            return true;
        }

        return super.onOptionsItemSelected(item);
    }
}
