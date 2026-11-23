@echo off
rem Lance tous les tests. Depuis la racine du projet : tests\lancer_tests.bat
for %%f in (test_niveau1 test_niveau2 test_niveau3 test_coherence test_coherence_famille test_parente_explication test_cli) do (
    echo === %%f ===
    swipl -g run_tests -t halt tests/%%f.pl
)