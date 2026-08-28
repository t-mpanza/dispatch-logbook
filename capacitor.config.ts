import type { CapacitorConfig } from "@capacitor/cli";

const config: CapacitorConfig = {
  appId: "com.dispatch.diary",
  appName: "Dispatch Diary",
  webDir: "dist/client",
  backgroundColor: "#0b0c12",
  plugins: {
    SplashScreen: {
      launchShowDuration: 1800,
      launchAutoHide: true,
      backgroundColor: "#0b0c12",
      androidScaleType: "CENTER_CROP",
      showSpinner: false,
    },
    Keyboard: {
      resize: "body",
      style: "DARK",
      resizeOnFullScreen: true,
    },
    StatusBar: {
      style: "DARK",
      backgroundColor: "#0b0c12",
    },
    CapacitorUpdater: {
      autoUpdate: false,
    },
  },
  android: {
    allowMixedContent: true,
    backgroundColor: "#0b0c12",
  },
};

export default config;
