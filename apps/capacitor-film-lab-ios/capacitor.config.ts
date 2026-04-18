import type { CapacitorConfig } from "@capacitor/cli";

const config: CapacitorConfig = {
  appId: "com.chibatakumi.film.lab.ios",
  appName: "Filmtone",
  webDir: "dist",
  ios: {
    contentInset: "automatic",
  },
  server: {
    androidScheme: "https",
  },
};

export default config;
