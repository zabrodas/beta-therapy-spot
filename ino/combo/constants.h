#include <ESP8266WiFi.h>


#define PROGMEM_S(s) (s)
#define NUM_ITEMS(x) (sizeof(x)/sizeof(*x))

//IO index  ESP8266 pin IO index  ESP8266 pin
//0 [*] GPIO16  7 GPIO13
//1 GPIO5 8 GPIO15
//2 GPIO4 9 GPIO3
//3 GPIO0 10  GPIO1
//4 GPIO2 11  GPIO9
//5 GPIO14  12  GPIO10
//6 GPIO12

static const char modepin=16;
static const char smokePin=12;
static const char domap[]={5,4,0,14};
static const char numdo=NUM_ITEMS(domap);


struct CKsVs {
  const char *k,*v;
};

static const CKsVs netList[]={
    { PROGMEM_S("az-theater"),PROGMEM_S("internal17") },
    { PROGMEM_S("gzabrodina"),PROGMEM_S("pusya756nadya") }
};

static const char wifiApConfig_ssid[]="az-theater-dmx";
static const char wifiApConfig_pwd[]="internal18";

IPAddress wifiApConfig_ip(192,168,33,1);
IPAddress wifiApConfig_gateway(192,168,33,1);
IPAddress wifiApConfig_netmask(255,255,255,0);

  
static const PROGMEM char serverReply[]=
      "HTTP/1.0 200 OK\r\n"
      "Content-Type: text/plain\r\n"
      "Access-Control-Allow-Origin: *\r\n"
      "Content-Length: 6\r\n"
      "\r\n"
      "COMBO1";

static const PROGMEM char serverState[]=
      "HTTP/1.0 200 OK\r\n"
      "Content-Type: application/javascript\r\n"
      "Access-Control-Allow-Origin: *\r\n"
      "\r\n"
      "{\"do\":[#DO1#,#DO2#,#DO3#,#DO4#],\"dmx\":\"#DMX#\"}";

static const PROGMEM char serverErr[]=
      "HTTP/1.0 404 Not found\r\n"
      "Content-Type: text/plain\r\n"
      "Content-Length: 9\r\n"
      "\r\n"
      "Not found";

static const PROGMEM char serverRedirect[]=
      "HTTP/1.0 302 Found\r\n"
      "Location: /file/index.html\r\n"
      "\r\nRedirected";

static const PROGMEM CKsVs mimeTypes[]={
  { PROGMEM_S("png"),  PROGMEM_S("image/png") },
  { PROGMEM_S("jpg"),  PROGMEM_S("image/jpeg") },
  { PROGMEM_S("gif"),  PROGMEM_S("image/gif") },
  { PROGMEM_S("html"), PROGMEM_S("text/html") },
  { PROGMEM_S("css"),  PROGMEM_S("text/css") },
  { PROGMEM_S("js"),   PROGMEM_S("application/javascript") }
};


static PROGMEM const char html_colorcalc_min_js[]=
#include "./html/colorcalc-min.js.h"
;
static PROGMEM const char html_index_htm[]=
#include "./html/index.html.h"
;
static PROGMEM const char html_jquery_321_min[]=
#include "./html/jquery-3.2.1.min.js.h"
;
static PROGMEM const char html_main_min_css[]=
#include "./html/main-min.css.h"
;
static PROGMEM const char html_script_min[]=
#include "./html/script-min.js.h"
;
static PROGMEM const char html_spectrum_min_css[]=
#include "./html/spectrum-min.css.h"
;
static PROGMEM const char html_spectrum_min_js[]=
#include "./html/spectrum-min.js.h"
;

struct CPgmKsVs {
  const char *k;
  const char *type;
  int length;
  PGM_P v;
};

static PROGMEM const CPgmKsVs staticContentDir[]={
  { "colorcalc-min.",   "js",     sizeof(html_colorcalc_min_js)-1,  html_colorcalc_min_js   },
  { "index.",           "html",   sizeof(html_index_htm)-1,         html_index_htm          },
  { "jquery-3.2.1.min.","js",     sizeof(html_jquery_321_min)-1,    html_jquery_321_min     },
  { "main-min.",        "css",    sizeof(html_main_min_css)-1,      html_main_min_css       },
  { "script-min.",      "js",     sizeof(html_script_min)-1,        html_script_min         },
  { "spectrum-min.",    "css",    sizeof(html_spectrum_min_css)-1,  html_spectrum_min_css   },
  { "spectrum-min.",    "js",     sizeof(html_spectrum_min_js)-1,   html_spectrum_min_js    }
};
