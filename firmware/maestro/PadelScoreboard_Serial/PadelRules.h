#pragma once
#include <Arduino.h>

struct Score {
  uint8_t ptsA;   // puntos del juego actual
  uint8_t ptsB;
  uint8_t gamesA;
  uint8_t gamesB;
  uint8_t setsA;
  uint8_t setsB;
  bool tieBreak;
  uint8_t tbA;
  uint8_t tbB;
  bool matchOver;
};

void resetMatch(Score &s);
void resetGame(Score &s);
void pointToA(Score &s);
void pointToB(Score &s);
bool isDeuce(const Score &s);
bool advA(const Score &s);
bool advB(const Score &s);
void formatPointStr(const Score &s, char *outA, char *outB, size_t n);
