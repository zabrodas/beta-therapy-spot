
#include "./constants.h"
#include <EEPROM.h>
#include <cont.h>

#define LOGLINE { Serial. print("line: "); Serial.println(__LINE__); Serial.flush(); }


auto smokeTimer=millis();

void smokeOff() {
    pinMode(smokePin, OUTPUT);
    digitalWrite(smokePin,LOW);
    smokeTimer=millis();
    Serial.println("Smoke off");
}

void smokeOn(int dur) {
    if (dur<=0 or dur>30) {
      smokeOff();
      return;
    }
    smokeTimer=millis()+dur*1000;
    digitalWrite(smokePin,HIGH);
    Serial.print("Smoke on ");
    Serial.println(dur);
}

void checkSmoke() {
  if (digitalRead(smokePin)==HIGH && int(millis()-smokeTimer)>=0) smokeOff();
}

auto &dmxSerial=Serial1;
auto dmxTimer=micros();
int dmxSerialINternalBufferLength=0;
char dmxBuffer[256];
const int dmxBufMaxLen=sizeof(dmxBuffer);
int dmxBufLen=0;
int dmxBufTrCnt=0;
int dmxCycleCnt=0;
char dmxDelay=0;
const int dmxBd1=ESP8266_CLOCK / 80000;
const int dmxBd2=ESP8266_CLOCK / 256000;
const int dmxClk=5000000;
const int dmxCharPerIsr=5;
const int dmxDelay1=(dmxCharPerIsr+1)*(5000000*12/256000);
const int dmxDelay2=2*(5000000*12/80000);
int dmxIsrCnt=0;


void dmxInit() {
  dmxSerial.begin(80000,SERIAL_8N2);
  dmxSerial.write(0);
  dmxSerial.flush();
  dmxSerialINternalBufferLength=dmxSerial.availableForWrite();
  dmxBufTrCnt=-3;
  dmxBuffer[0]=0;
  dmxBufLen=1;
  dmxDelay=0;
}



static void ICACHE_RAM_ATTR xtimer1_enable(uint8_t divider, uint8_t int_type, uint8_t reload){
    T1C = (1 << TCTE) | ((divider & 3) << TCPD) | ((int_type & 1) << TCIT) | ((reload & 1) << TCAR);
    T1I = 0;
}

static void ICACHE_RAM_ATTR xtimer1_write(uint32_t ticks){
    T1L = ((ticks)& 0x7FFFFF);
    if ((T1C & (1 << TCIT)) == 0) TEIE |= TEIE1;//edge int enable
}

static void ICACHE_RAM_ATTR xtimer1_isr_handler(void *para){
  if ((T1C & ((1 << TCAR) | (1 << TCIT))) == 0) TEIE &= ~TEIE1;//edge int disable
  T1I = 0;
  dmxIsrCnt++;

  switch (dmxBufTrCnt) {
    case -3:
      USD(1) = dmxBd1;
      USF(1) = 0;
      dmxBufTrCnt=-1;
      T1L = dmxDelay2;
      break;
    case -1:
      USD(1) = dmxBd2;
      dmxBufTrCnt=0;
      T1L = dmxDelay1;
      break;
    default: {
        int e=dmxBufTrCnt+dmxCharPerIsr;
        if (e>dmxBufLen) e=dmxBufLen;
        while (dmxBufTrCnt<e) USF(1) = dmxBuffer[dmxBufTrCnt++];
        if (dmxBufTrCnt<dmxBufLen) {
          T1L = dmxDelay1;
        } else {
          dmxBufTrCnt=-3;
          dmxCycleCnt++;
          T1L = dmxDelay2;
        }
      }
      break;
  }
  if ((T1C & (1 << TCIT)) == 0) TEIE |= TEIE1;//edge int enable  
}

static void ICACHE_RAM_ATTR xtimer1_isr_init(){
    ETS_FRC_TIMER1_INTR_ATTACH(xtimer1_isr_handler, NULL);
    ETS_FRC1_INTR_ENABLE();
}


void checkDmxSendFrameIsr(){
  switch (dmxBufTrCnt) {
    case -3:
      USD(1) = dmxBd1;
      USF(1) = 0;
      dmxBufTrCnt=-1;
      xtimer1_write(dmxDelay2);
      break;
    case -1:
      USD(1) = dmxBd2;
      dmxBufTrCnt=0;
      xtimer1_write(dmxDelay1);
      break;
    default: {
        if (dmxBufTrCnt>=0 && dmxBufTrCnt<dmxBufLen) {
          USF(1) = dmxBuffer[dmxBufTrCnt++];
          xtimer1_write(dmxDelay1);
        } else {
          dmxBufTrCnt=-3;
          dmxCycleCnt++;
          xtimer1_write(dmxDelay2);
        }
      }
      break;
  }
}



void checkDmxSendFrame(){
  switch (dmxBufTrCnt) {
    case -3:
      dmxSerial.begin(80000,SERIAL_8N2);
      dmxSerial.write(0);
      dmxBufTrCnt++;
      dmxTimer=micros();
      break;
    case -2:
      if (micros()-dmxTimer>1000000ul*16ul/80000ul) dmxBufTrCnt++;
      break;
    case -1:
      dmxSerial.begin(256000,SERIAL_8N2);
      dmxBufTrCnt++;
    default:
      while (dmxSerial.availableForWrite()) {
        if (dmxBufTrCnt>=0 && dmxBufTrCnt<dmxBufLen) {
          dmxSerial.write(dmxBuffer[dmxBufTrCnt++]);
        } else {
          if (dmxSerialINternalBufferLength==dmxSerial.availableForWrite()) {
            dmxSerial.flush();
            dmxBufTrCnt=-3;
            dmxCycleCnt++;
          }
          break;
        }
      }
      break;
  }
}



void doCtrl(int i, char on) {
    if (i<0 && i>=numdo) return;
    int pin=domap[i];
    pinMode(pin, OUTPUT);
    digitalWrite(pin, on>0 ? HIGH : LOW);
}
int doState(int i) {
    if (i<0 && i>=numdo) return 0;
    int pin=domap[i];
    return digitalRead(pin)==HIGH;
}
void doInit() {
  for (int i=0; i<numdo; i++) doCtrl(i,0);
}

WiFiServer httpSserver(8080);


int matchChar(const char *&p, const char c) {
  if (*p!=c) return 0;
  p++; return 1;
}
int matchWs(const char *&p) {
  while (matchChar(p,' ')) { }
  return 1;
}
int matchStr(const char *&p, const char *m) {
  const char *p1=p;
  while (*m) {
    if (!matchChar(p1, *m)) return 0;
    m++;
  }
  p=p1; return 1;
}
int matchInt(const char *&p, int &value) {
  int v=0;
  const char *p1=p;
  for (;;) {
    if (*p1>='0' && *p1<='9') {
      v=v*10+*p1-'0';
      p1++;
    } else {
      break;
    }
  }
  if (p1!=p) {
    p=p1;
    value=v;
    return 1;
  } else {
    return 0;
  }
}
int matchHex1(const char *&p, int &value) {
  if (*p>='0' && *p<='9') { value=(*p++)-'0'; return 1; }
  if (*p>='a' && *p<='f') { value=(*p++)-'a'+10; return 1; }
  if (*p>='A' && *p<='F') { value=(*p++)-'A'+10; return 1; }
  return 0;
}
int matchHex2(const char *&p, int &value) {
  const char *p1=p;
  int v1,v2;
  if (matchHex1(p1,v1) && matchHex1(p1,v2)) {
    p=p1; value=(v1<<4)|v2;
    return 1;
  }
  return 0;
}

const char *fileType2mimeType(const char *ft) {
  for (int i=0; i<NUM_ITEMS(mimeTypes); i++) {
    if (strcmp(mimeTypes[i].k,ft)==0) return mimeTypes[i].v;
  }
  return "application/octet-stream";
}

void sendPstr(WiFiClient &client, const char *ps, int len=-1) {
  if (len<0) {
    for(;;) {
      char c=pgm_read_byte(ps);
      if (!c) break;
      client.write(c);
      ps++;
    }
  } else {
    while (len>0) {
      char c=pgm_read_byte(ps);
      if (!c) break;
      client.write(c);
      len--; ps++;
    }
    
  }
}

void sendHex1(WiFiClient &client, int v) {
  client.write("0123456789ABCDEF"[v&15]);
}

void sendHex2(WiFiClient &client, int v) {
  sendHex1(client, v>>4);
  sendHex1(client, v);
}

void send200(WiFiClient &client) {
  sendPstr(client,serverReply);
}
void send404(WiFiClient &client) {
  sendPstr(client,serverErr);
}
void sendRedirectToIndex(WiFiClient &client) {
  sendPstr(client,serverRedirect);
}


void httpServerCheck() {
  WiFiClient client = httpSserver.available();
  if (!client) return;
  String req = client.readStringUntil('\r');
  Serial.print(F("REQ: "));
  Serial.println(req);
  const char *p=req.c_str();
  
  if (!matchStr(p,"GET")) { send404(client); return; } 
  if (!matchWs(p)) { send404(client); return; } 
  if (!matchChar(p,'/')) { send404(client); return; }

  if (matchChar(p,' ')) { sendRedirectToIndex(client); return; }

  if (matchStr(p,"file/")) {
    for (int i=0; i<NUM_ITEMS(staticContentDir); i++) {
      const char *p1=p;
      if (matchStr(p1,staticContentDir[i].k) && matchStr(p1,staticContentDir[i].type) && matchChar(p1,' ')) {
        client.print("HTTP/1.0 200 OK\r\n");
        client.print("Content-Type: "); client.print(fileType2mimeType(staticContentDir[i].type)); client.print("\r\n");
        client.print("Content-Length: "); client.print(staticContentDir[i].length); client.print("\r\n");
        client.print("\r\n");
        sendPstr(client,staticContentDir[i].v,staticContentDir[i].length);
        client.flush();
        return;
      }
    }
    send404(client);
    return;
  }

  int op=0;
  if (matchStr(p,"on")) op=1;
  else if (matchStr(p,"off")) op=2;
  else if (matchStr(p,"do")) op=3;
  else if (matchStr(p,"smoke")) op=4;
  else if (matchStr(p,"state")) op=5;
  else if (matchStr(p,"dmx")) op=6;
  else { send200(client); return; }

  int index;
  if (!matchInt(p,index)) index=1;
  
  matchStr(p,"=");

  switch (op) {
    case 1: doCtrl(index-1,1); send200(client); eepromRequestToSave(); break;
    case 2: doCtrl(index-1,0); send200(client); eepromRequestToSave(); break;
    case 3: {
      for (int i=0; i<numdo; i++) doCtrl(i,(index>>i)&1);
      send200(client);
      eepromRequestToSave();
      break;
    }
    case 4: smokeOn(index); send200(client); break;
    case 5:
        client.print("HTTP/1.0 200 OK\r\n");
        client.print("Content-Type: "); client.print(fileType2mimeType("json")); client.print("\r\n");
        client.print("\r\n");
        client.print("{\"do\":[");
        for (int i=0; i<numdo; i++) {
          if (i) client.print(",");
          client.print(doState(i));
        }
        client.print("],\"dmx\":\"");
        for (int i=1; i<dmxBufLen; i++) sendHex2(client,dmxBuffer[i]);
        client.print("\"}");
        break;

    case 6: {
      int l=1;
      dmxBuffer[0]=0;
      while (l<dmxBufMaxLen) {
        int v;
        if (!matchHex2(p,v)) break;
        dmxBuffer[l++]=v;
      }
      dmxBufLen=l;
      send200(client);
      eepromRequestToSave(); 
      break;
    }
    default:
      send404(client);
      break;
  }
  client.flush();
}


char wifiApMode;

void wifiInitAp() {
  Serial.println("Scanning WiFi...");
  WiFi.mode(WIFI_STA);
  WiFi.disconnect();
  delay(100);
  int n = WiFi.scanNetworks();
  int channelRssi[11]={-200,-200,-200,-200,-200,-200,-200,-200,-200,-200,-200};
  for (int i = 0; i < n; i++) {
    int rssi=WiFi.RSSI(i);
    int channel=WiFi.channel(i);
    if (channel>=1 && channel<=11 && rssi>channelRssi[channel-1]) channelRssi[channel-1]=rssi;
    Serial.printf("%s, Ch:%d (%ddBm) %s\n",WiFi.SSID(i).c_str(), channel, rssi, WiFi.encryptionType(i) == ENC_TYPE_NONE ? "open" : "secured");
  }
  int selChannel=1;
  int minRssi=0;
  for (int i = 1; i < 11; i++) {
    if (channelRssi[i-1]<minRssi) {
      minRssi=channelRssi[i-1];
      selChannel=i;
    }
  }
  
  Serial.printf("Starting AP SSID=%s Pwd=%s Ch=%d Ip=", wifiApConfig_ssid, wifiApConfig_pwd, selChannel);
  WiFi.mode(WIFI_AP);
  WiFi.softAPConfig(wifiApConfig_ip, wifiApConfig_gateway, wifiApConfig_netmask);
  WiFi.softAP(wifiApConfig_ssid, wifiApConfig_pwd, selChannel,0 ,8);
  Serial.println(WiFi.softAPIP());

  httpSserver.begin();

}

auto wifiConnTimer=millis();
char netListIndex;
const int wifiConnTestInterval=5000;
int wifiConnRetry=0;
char wifiConnected=0;

void wifiInitSta() {
  Serial.println("init WiFi STA...");
  Serial.flush();
  WiFi.mode(WIFI_STA);
//  WiFi.disconnect();
  delay(100);
  wifiConnTimer=millis();
  netListIndex=0;
  wifiConnRetry=1;
  wifiConnected=1;
  Serial.println("Starting WiFi STA...");
  Serial.flush();
  wifiCheckStaConn();
}

void wifiCheckStaConn() {
  if (wifiApMode || int(millis()-wifiConnTimer)<0) return;
  int ws=WiFi.status();
  if (WiFi.status()!=WL_CONNECTED) {
    if (wifiConnected) {
      wifiConnected=0;
      Serial.println("WiFi not connected");
      httpSserver.close();
      Serial.println("Stop HTTP server");
    }
    if (wifiConnRetry<=0) {
      if (++netListIndex>=NUM_ITEMS(netList)) netListIndex=0;
    } else {
      wifiConnRetry--;
    }
    const char *ssid=netList[netListIndex].k;
    const char *pass=netList[netListIndex].v;
    Serial.printf("Attempt %d to connect to %s with %s\n", wifiConnRetry, ssid, pass);
    WiFi.begin(ssid, pass);
    wifiConnTimer=millis()+10000;
  } else {
    if (!wifiConnected) {
      wifiConnected=1;
      Serial.print("WiFi connected IP=");
      Serial.println(WiFi.localIP());
      Serial.println("Starting HTTP server");
      httpSserver.begin();
    }
    wifiConnRetry=2;
    wifiConnTimer=millis()+5000;
  }
}

void initWiFi() {
    pinMode(modepin,INPUT_PULLUP);
    wifiApMode=digitalRead(modepin)==LOW;
    if (wifiApMode) {
      wifiInitAp();
    } else {
      wifiInitSta();
    }
}

auto eepromTimer=millis();
char eepromNeedSave=0;

void eepromInit() {
    EEPROM.begin(512);
}
void eepromSaveState() {
  auto t0=millis();
  Serial.println("EEPROM saving state...");
  int a=0;
  for (int i=0; i<numdo; i++) {
    EEPROM.write(a++, doState(i));
  }
  EEPROM.write(a++, dmxBufLen&0xff);
  EEPROM.write(a++, (dmxBufLen>>8)&0xff);
  for (int i=0; i<dmxBufLen; i++) {
    EEPROM.write(a++, dmxBuffer[i]);
  }
  if (EEPROM.commit()) {
    Serial.printf("EEROM saved %d byte duration=%ld\n",a,(unsigned long)(millis()-t0));
  } else {
    Serial.println("EEPROM commit error");
  }
}

void eepromCheck() {
  if (eepromNeedSave && millis()-eepromTimer>1000) {
    eepromSaveState();
    eepromNeedSave=0;
  }
}

void eepromRequestToSave() {
  eepromNeedSave=1;
  eepromTimer=millis();
}

void eepromRestoreState() {
  
  int a=0;
  for (int i=0; i<numdo; i++) {
    doCtrl(i, EEPROM.read(a++));
  }
  dmxBufLen=EEPROM.read(a++);
  dmxBufLen|=EEPROM.read(a++)<<8;
  if (dmxBufLen<0) dmxBufLen=0;
  if (dmxBufLen>dmxBufMaxLen) dmxBufLen=dmxBufMaxLen;
  for (int i=0; i<dmxBufLen; i++) {
    dmxBuffer[i]=EEPROM.read(a++);
  }
  Serial.printf("EEPROM restored %d bytes\n",a);
}



auto watchDogTimer=millis();
unsigned long cycleCnt=0;


void dmxIntSetup() {
  Serial.println(dmxBd1);
  Serial.println(dmxBd2);
  Serial.println(dmxClk);
  Serial.println(dmxDelay1);
  Serial.println(dmxDelay2);
  xtimer1_isr_init();
  xtimer1_enable(TIM_DIV16, TIM_EDGE, TIM_SINGLE);
  xtimer1_write(10000);
}


void setup() {
  Serial.begin(115200);
  Serial.println("Starting");
  Serial.flush();
  smokeOff();
  doInit();
  dmxInit();
  initWiFi();
  eepromInit();
  eepromRestoreState();
  watchDogTimer=millis();
  cycleCnt=0;
  dmxIntSetup();
}

void loop() {
  auto t=millis();
  if (t-watchDogTimer>1000u) {
    watchDogTimer=t;
    Serial.print("Cnt="); Serial.print(cycleCnt);
    Serial.print(" dmxIsrCnt="); Serial.print(dmxIsrCnt);
    Serial.print(" DmxCnt="); Serial.println(dmxCycleCnt);
    cycleCnt=0; dmxCycleCnt=0; dmxIsrCnt=0;
  }
  checkSmoke();
//  checkDmxSendFrame();
  wifiCheckStaConn();
  httpServerCheck();
  eepromCheck();
  cycleCnt++;
}
