// Dump decompiled functions + program summary.
// 用法: -postScript DumpDecomp.java <outDir> [maxFunctions]
//@category RE
import ghidra.app.decompiler.DecompInterface;
import ghidra.app.decompiler.DecompileResults;
import ghidra.app.script.GhidraScript;
import ghidra.program.model.listing.Function;
import ghidra.program.model.listing.FunctionIterator;

import java.io.File;
import java.io.PrintWriter;

public class DumpDecomp extends GhidraScript {

    @Override
    public void run() throws Exception {
        String[] args = getScriptArgs();
        File outDir = new File(args.length > 0 ? args[0] : "out");
        int max = args.length > 1 ? Integer.parseInt(args[1]) : 50;
        outDir.mkdirs();

        int funcCount = 0;
        FunctionIterator fit = currentProgram.getFunctionManager().getFunctions(true);
        while (fit.hasNext()) { fit.next(); funcCount++; }

        try (PrintWriter w = new PrintWriter(new File(outDir, "summary.txt"), "UTF-8")) {
            w.println("program: " + currentProgram.getName());
            w.println("language: " + currentProgram.getLanguageID());
            w.println("compiler: " + currentProgram.getCompilerSpec().getCompilerSpecID());
            w.println("imageBase: " + currentProgram.getImageBase());
            w.println("minAddress: " + currentProgram.getMinAddress());
            w.println("maxAddress: " + currentProgram.getMaxAddress());
            w.println("functions: " + funcCount);
            w.println("symbols: " + currentProgram.getSymbolTable().getNumSymbols());
        }

        DecompInterface di = new DecompInterface();
        di.toggleCCode(true);
        di.openProgram(currentProgram);

        int done = 0;
        try (PrintWriter w = new PrintWriter(new File(outDir, "decompiled.c"), "UTF-8")) {
            FunctionIterator it = currentProgram.getFunctionManager().getFunctions(true);
            while (it.hasNext() && (max <= 0 || done < max)) {
                Function f = it.next();
                if (f.isThunk() || f.isExternal()) { continue; }
                w.println("/* " + f.getName() + " @ " + f.getEntryPoint() + " */");
                try {
                    DecompileResults res = di.decompileFunction(f, 60, monitor);
                    if (res.decompileCompleted()) {
                        w.println(res.getDecompiledFunction().getC());
                    } else {
                        w.println("// <decompile failed: " + res.getErrorMessage() + ">");
                    }
                } catch (Exception e) {
                    w.println("// <exception: " + e.getMessage() + ">");
                }
                w.println();
                done++;
            }
            w.flush();
        }
        di.dispose();
        println("DumpDecomp: " + done + "/" + funcCount + " functions -> " + outDir);
    }
}
