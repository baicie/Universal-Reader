import { Buffer } from "buffer";
import { registerRootComponent } from "expo";

import App from "./App";

globalThis.Buffer = Buffer;

registerRootComponent(App);
