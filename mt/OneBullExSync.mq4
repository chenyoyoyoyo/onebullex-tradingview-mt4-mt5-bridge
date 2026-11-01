//+------------------------------------------------------------------+
//| OneBullExSync.mq4                                                |
//| Sync MT4 positions to a OneBullEx Spartans bot account through   |
//| the OneBullEx TradingView Bridge webhook receiver.               |
//|                                                                  |
//| The EA does not trade on MT4. Every few seconds it reads the     |
//| open orders of the mapped symbols, converts lots to units        |
//| (lots x contract size, e.g. ounces of gold) and sends the        |
//| target position to the receiver. The receiver adjusts the        |
//| OneBullEx position to match (target position, so resends are     |
//| safe and never double the position).                             |
//|                                                                  |
//| Setup: Tools > Options > Expert Advisors >                       |
//|   [x] Allow WebRequest for listed URL: add your server address,  |
//|       e.g. https://203-0-113-10.sslip.io                         |
//| MIT License                                                      |
//+------------------------------------------------------------------+
#property copyright "OneBullEx TradingView Bridge contributors"
#property link      "https://github.com/chenyoyoyoyo/onebullex-tradingview-bridge"
#property version   "1.00"
#property strict

input string WebhookURL    = "https://YOUR-SERVER.sslip.io/webhook"; // Webhook URL from install.sh https
input string Passphrase    = "";                       // Passphrase from install.sh install
input string SymbolMap     = "XAUUSD=XAUSPARTANS_USDT"; // MT4 symbol=OneBullEx symbol, comma separated
input double Multiplier    = 1.0;    // OneBullEx size = MT4 size x Multiplier
input bool   HedgeMode     = false;  // false: send net position; true: send long and short separately
input int    MagicFilter   = -1;     // -1 = all orders; otherwise only orders with this magic number
input int    PollSeconds   = 1;      // How often to check positions
input int    ResendSeconds = 60;     // Resend unchanged position every N seconds (0 = only on change)
input int    LockAccount   = 0;      // Only sync this account number (0 = the account at start)

string g_mt[];
string g_obx[];
double g_lastLong[];
double g_lastShort[];
datetime g_lastTime[];
bool   g_sent[];
string g_status[];
int    g_account = 0;

string Trim(string s)
  {
   int n = StringLen(s), a = 0, b = n - 1;
   while(a < n && StringGetCharacter(s, a) <= ' ') a++;
   while(b >= a && StringGetCharacter(s, b) <= ' ') b--;
   if(b < a) return("");
   return(StringSubstr(s, a, b - a + 1));
  }

bool ParseMap()
  {
   string items[];
   int n = StringSplit(SymbolMap, ',', items);
   int count = 0;
   for(int i = 0; i < n; i++)
     {
      string kv[];
      if(StringSplit(items[i], '=', kv) != 2) continue;
      string mt = Trim(kv[0]), obx = Trim(kv[1]);
      if(mt == "" || obx == "") continue;
      count++;
      ArrayResize(g_mt, count);    g_mt[count - 1] = mt;
      ArrayResize(g_obx, count);   g_obx[count - 1] = obx;
      ArrayResize(g_lastLong, count);  g_lastLong[count - 1] = 0;
      ArrayResize(g_lastShort, count); g_lastShort[count - 1] = 0;
      ArrayResize(g_lastTime, count);  g_lastTime[count - 1] = 0;
      ArrayResize(g_sent, count);      g_sent[count - 1] = false;
      ArrayResize(g_status, count);    g_status[count - 1] = "waiting";
     }
   return(count > 0);
  }

int OnInit()
  {
   if(StringLen(Passphrase) < 12)
     {
      Alert("OneBullExSync: Passphrase is empty or too short. Copy it from install.sh output.");
      return(INIT_PARAMETERS_INCORRECT);
     }
   if(StringFind(WebhookURL, "https://") != 0 || StringFind(WebhookURL, "YOUR-SERVER") >= 0)
     {
      Alert("OneBullExSync: set WebhookURL to your https://.../webhook address.");
      return(INIT_PARAMETERS_INCORRECT);
     }
   if(Multiplier <= 0)
     {
      Alert("OneBullExSync: Multiplier must be greater than 0.");
      return(INIT_PARAMETERS_INCORRECT);
     }
   if(!ParseMap())
     {
      Alert("OneBullExSync: SymbolMap is empty. Example: XAUUSD=XAUSPARTANS_USDT");
      return(INIT_PARAMETERS_INCORRECT);
     }
   g_account = (LockAccount > 0) ? LockAccount : AccountNumber();
   EventSetTimer(PollSeconds > 1 ? PollSeconds : 1);
   SyncAll();
   return(INIT_SUCCEEDED);
  }

void OnDeinit(const int reason)
  {
   EventKillTimer();
   Comment("");
  }

void OnTimer() { SyncAll(); }
void OnTick()  { }

// Sum open market orders of one symbol, in units (lots x contract size).
bool Exposure(string sym, double &longUnits, double &shortUnits)
  {
   longUnits = 0;
   shortUnits = 0;
   double cs = MarketInfo(sym, MODE_LOTSIZE);
   if(cs <= 0) return(false);
   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) return(false);
      if(OrderSymbol() != sym) continue;
      if(MagicFilter >= 0 && OrderMagicNumber() != MagicFilter) continue;
      if(OrderType() == OP_BUY)       longUnits  += OrderLots() * cs;
      else if(OrderType() == OP_SELL) shortUnits += OrderLots() * cs;
     }
   return(true);
  }

string Num(double v) { return(DoubleToString(v, 8)); }

bool Send(string obx, double longUnits, double shortUnits, string &status)
  {
   string body = "{\"passphrase\":\"" + Passphrase + "\",\"symbol\":\"" + obx +
                 "\",\"unit\":\"coin\",\"multiplier\":" + Num(Multiplier) + ",\"source\":\"mt4\",";
   if(HedgeMode)
      body += "\"long\":" + Num(longUnits) + ",\"short\":" + Num(shortUnits) + "}";
   else
      body += "\"target\":" + Num(longUnits - shortUnits) + "}";

   char data[], result[];
   string headers;
   int len = StringToCharArray(body, data, 0, -1, CP_UTF8);
   if(len > 0) ArrayResize(data, len - 1);   // drop the trailing zero
   ResetLastError();
   int code = WebRequest("POST", WebhookURL, "Content-Type: application/json\r\n", 5000, data, result, headers);
   if(code == -1)
     {
      int err = GetLastError();
      status = "WebRequest error " + IntegerToString(err);
      if(err == 4060 || err == 4014)
         status += " (add the server address in Tools > Options > Expert Advisors > Allow WebRequest)";
      Print("OneBullExSync: ", obx, " ", status);
      return(false);
     }
   string reply = CharArrayToString(result, 0, -1, CP_UTF8);
   if(code != 200)
     {
      status = "HTTP " + IntegerToString(code) + " " + reply;
      Print("OneBullExSync: ", obx, " ", status);
      return(false);
     }
   status = "sent " + TimeToString(TimeLocal(), TIME_DATE | TIME_SECONDS);
   return(true);
  }

void SyncAll()
  {
   string head = "OneBullExSync  " + (HedgeMode ? "hedge" : "net") + " mode  x" + DoubleToString(Multiplier, 4);
   if(g_account == 0) g_account = AccountNumber();
   if(!IsConnected())
     {
      Comment(head, "\nMT4 not connected to broker - waiting");
      return;
     }
   if(AccountNumber() != g_account)
     {
      Comment(head, "\nAccount ", AccountNumber(), " is not the locked account ", g_account, " - not syncing");
      return;
     }
   string lines = "";
   for(int i = 0; i < ArraySize(g_mt); i++)
     {
      double lu, su;
      if(!Exposure(g_mt[i], lu, su))
        {
         lines += "\n" + g_mt[i] + ": symbol not found or orders unreadable";
         continue;
        }
      bool changed = !g_sent[i] || MathAbs(lu - g_lastLong[i]) > 1e-9 || MathAbs(su - g_lastShort[i]) > 1e-9;
      bool due = ResendSeconds > 0 && TimeLocal() - g_lastTime[i] >= ResendSeconds;
      if(changed || due)
        {
         string st;
         if(Send(g_obx[i], lu, su, st))
           {
            g_lastLong[i] = lu;
            g_lastShort[i] = su;
            g_lastTime[i] = TimeLocal();
            g_sent[i] = true;
           }
         g_status[i] = st;
        }
      lines += "\n" + g_mt[i] + " -> " + g_obx[i] + "  long " + DoubleToString(lu, 4) +
               "  short " + DoubleToString(su, 4) + "  |  " + g_status[i];
     }
   Comment(head, lines);
  }
//+------------------------------------------------------------------+
