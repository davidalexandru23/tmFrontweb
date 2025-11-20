import 'package:flutter/material.dart';

// NOU: Am scos '_' din nume pentru a o face publică
class DelegationChainWidget extends StatelessWidget {
  final List<String> chain;
  final bool isSmall;

  // NOU: Avem nevoie și de ID-ul user-ului logat pentru a ști cine e "Tu"
  final String currentUsername;

  const DelegationChainWidget({
    super.key,
    required this.chain,
    required this.currentUsername, // NOU
    this.isSmall = false,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 4.0,
      runSpacing: 4.0,
      children: List.generate(chain.length * 2 - 1, (index) {
        if (index.isEven) {
          final itemIndex = index ~/ 2;
          final name = chain[itemIndex];
          // NOU: Logica pentru "Tu" este acum bazată pe nume
          final isYou = (name == currentUsername);

          return Chip(
            padding: isSmall
                ? const EdgeInsets.all(2.0)
                : const EdgeInsets.all(8.0),
            backgroundColor: isYou ? Colors.red[800] : Colors.grey[800],
            label: Text(
              isYou ? "Tu ($name)" : name, // NOU: Afișăm "Tu (Nume)"
              style: TextStyle(
                color: Colors.white,
                fontWeight: isYou ? FontWeight.bold : FontWeight.normal,
                fontSize: isSmall ? 10 : 14,
              ),
            ),
            avatar: Icon(
              isYou ? Icons.account_circle : Icons.person_pin_circle,
              color: Colors.white,
              size: isSmall ? 14 : 18,
            ),
          );
        } else {
          return Icon(
            Icons.arrow_right_alt,
            color: Colors.red,
            size: isSmall ? 16 : 24,
          );
        }
      }),
    );
  }
}
