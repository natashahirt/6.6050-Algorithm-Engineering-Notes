@echo off
echo Compiling LaTeX document...
pdflatex main.tex
pdflatex main.tex
echo Compilation complete! Check main.pdf

echo Cleaning up auxiliary files...
del *.aux 2>nul
del *.log 2>nul
del *.out 2>nul
del *.toc 2>nul
del *.synctex.gz 2>nul
del *.fdb_latexmk 2>nul
del *.fls 2>nul

echo Cleaning up auxiliary files in chapters directory...
del chapters\*.aux 2>nul
del chapters\*.log 2>nul
del chapters\*.out 2>nul
del chapters\*.toc 2>nul
del chapters\*.synctex.gz 2>nul
del chapters\*.fdb_latexmk 2>nul
del chapters\*.fls 2>nul
echo Cleanup complete!

pause
