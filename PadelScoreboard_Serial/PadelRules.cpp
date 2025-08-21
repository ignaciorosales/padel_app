#include "PadelRules.h"
#include "Config.h"

static void pushGameWin(Score &s, bool teamA);
static void pushSetWin(Score &s, bool teamA);

void resetMatch(Score &s) {
  s.ptsA = s.ptsB = 0;
  s.gamesA = s.gamesB = 0;
  s.setsA = s.setsB = 0;
  s.tieBreak = false;
  s.tbA = s.tbB = 0;
  s.matchOver = false;
}

void resetGame(Score &s) {
  if (s.tieBreak) {
    s.tieBreak = false;
    s.tbA = s.tbB = 0;
  }
  s.ptsA = s.ptsB = 0;
}

static bool gameWon(uint8_t me, uint8_t opp) {
  return (me >= 4 && me >= opp + 2);
}

static bool tiebreakWon(uint8_t me, uint8_t opp) {
  return (me >= 7 && me >= opp + 2);
}

static void pushGameWin(Score &s, bool teamA) {
  if (teamA) s.gamesA++; else s.gamesB++;
  s.ptsA = s.ptsB = 0;

  if (!s.tieBreak) {
    uint8_t me = teamA ? s.gamesA : s.gamesB;
    uint8_t opp = teamA ? s.gamesB : s.gamesA;

    if ((me >= 6 && me >= opp + 2)) {
      pushSetWin(s, teamA);
      return;
    }
    if (s.gamesA == 6 && s.gamesB == 6) {
      s.tieBreak = true;
      s.tbA = s.tbB = 0;
    }
  }
}

static void pushSetWin(Score &s, bool teamA) {
  if (teamA) s.setsA++; else s.setsB++;
  s.gamesA = s.gamesB = 0;
  s.tieBreak = false;
  s.tbA = s.tbB = 0;

  if (s.setsA >= SETS_PARA_GANAR || s.setsB >= SETS_PARA_GANAR) {
    s.matchOver = true;
  }
}

void pointToA(Score &s) {
  if (s.matchOver) return;

  if (s.tieBreak) {
    s.tbA++;
    if (tiebreakWon(s.tbA, s.tbB)) {
      pushSetWin(s, true);
    }
    return;
  }

  s.ptsA++;
  if (gameWon(s.ptsA, s.ptsB)) {
    pushGameWin(s, true);
  }
}

void pointToB(Score &s) {
  if (s.matchOver) return;

  if (s.tieBreak) {
    s.tbB++;
    if (tiebreakWon(s.tbB, s.tbA)) {
      pushSetWin(s, false);
    }
    return;
  }

  s.ptsB++;
  if (gameWon(s.ptsB, s.ptsA)) {
    pushGameWin(s, false);
  }
}

bool isDeuce(const Score &s) {
  if (s.tieBreak) return false;
  return (s.ptsA >= 3 && s.ptsB >= 3 && s.ptsA == s.ptsB);
}

bool advA(const Score &s) {
  if (s.tieBreak) return false;
  return (s.ptsA >= 4 && s.ptsA == s.ptsB + 1);
}

bool advB(const Score &s) {
  if (s.tieBreak) return false;
  return (s.ptsB >= 4 && s.ptsB == s.ptsA + 1);
}

static const char* toTennis(uint8_t p) {
  switch (p) {
    case 0: return "0";
    case 1: return "15";
    case 2: return "30";
    default: return "40";
  }
}

void formatPointStr(const Score &s, char *outA, char *outB, size_t n) {
  if (s.tieBreak) {
    snprintf(outA, n, "%u", s.tbA);
    snprintf(outB, n, "%u", s.tbB);
    return;
  }
  if (isDeuce(s)) {
    snprintf(outA, n, "40");
    snprintf(outB, n, "40");
    return;
  }
  if (advA(s)) {
    snprintf(outA, n, "Ad");
    snprintf(outB, n, "40");
    return;
  }
  if (advB(s)) {
    snprintf(outA, n, "40");
    snprintf(outB, n, "Ad");
    return;
  }
  snprintf(outA, n, "%s", toTennis(s.ptsA));
  snprintf(outB, n, "%s", toTennis(s.ptsB));
}
