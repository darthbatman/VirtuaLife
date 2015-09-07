package com.opteam.virtualight;

public class AccelData {
    private int xAcceleration;
    private int yAcceleration;
    private int zAcceleration;
    private long timeMillis;

    public AccelData(String[] splitData) {
        xAcceleration = Integer.parseInt(splitData[0]);
        yAcceleration = Integer.parseInt(splitData[1]);
        zAcceleration = Integer.parseInt(splitData[2]);
        timeMillis = Long.parseLong(splitData[3]);
    }

    @Override
    public String toString() {
        return "AccelData{" +
                "xAcceleration=" + xAcceleration +
                ", yAcceleration=" + yAcceleration +
                ", zAcceleration=" + zAcceleration +
                ", timeMillis=" + timeMillis +
                '}';
    }

    public int getxAcceleration() {
        return xAcceleration;
    }

    public int getyAcceleration() {
        return yAcceleration;
    }

    public int getzAcceleration() {
        return zAcceleration;
    }

    public long getTimeMillis() {
        return timeMillis;
    }
}
