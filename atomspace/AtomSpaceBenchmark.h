#ifndef _OPENCOG_AS_BENCHMARK_H
#define _OPENCOG_AS_BENCHMARK_H

#include <random>
#include <boost/tuple/tuple.hpp>

#include <opencog/util/mt19937ar.h>

#include <opencog/atomspace/AtomSpace.h>
#include <opencog/atoms/atom_types/types.h>
// #undef HAVE_CYTHON
// #undef HAVE_GUILE

using boost::tuple;

namespace opencog
{

typedef boost::tuple<clock_t,clock_t> timepair_t;

class PythonEval;
class SchemeEval;

class AtomSpaceBenchmark
{
    // size of AtomSpace, time taken for operation, rss memory max
    typedef boost::tuple<size_t,clock_t,long> record_t;


    struct TimeStats {
        clock_t t_total;
        clock_t t_max;
        clock_t t_min;
        clock_t t_mean;
        clock_t t_std;
        long t_N;
        TimeStats(const std::vector<record_t>& records);
        void print();
    };


    void recordToFile(std::ofstream& file, const record_t record) const;

    float linkSize_mean;

    Type defaultLinkType;
    float chanceOfNonDefaultLink;
    Type defaultNodeType;
    float chanceOfNonDefaultNode;

    float maxSize; //! never make the atomspace bigger than this while building it

    AtomSpace* asp;
    AtomTable* atab;
#if HAVE_GUILE
    SchemeEval* scm;
#endif
#if HAVE_CYTHON
    PythonEval* pyev;
#endif

    MT19937RandGen* randomGenerator;
    std::poisson_distribution<unsigned> *poissonDistribution;

    Type randomType(Type t);
    Type numberOfTypes;

    // Make Nclock random nodes of name "node <counter>" where counter
    // is incremented for each node. Or s if non empty.
    clock_t makeRandomNodes(const std::string& s);

	// Make Nclock random links with random arity and random
	// outgoings.
	clock_t makeRandomLinks();

    long getMemUsage();
    int counter;

    // Obtain memoized or compiled variant of a guile expr
    std::string memoize_or_compile(std::string, std::string);
    void guile_define(std::string, Handle);

    std::vector<std::string>  methodNames;

    unsigned int Nclock;
    unsigned int Nreps;
    unsigned int Nloops;
    int global;

public:
    unsigned int baseNclock;
    unsigned int baseNreps;
    unsigned int baseNloops;
    unsigned int Nreserve;

    bool memoize;
    bool compile;
    int sizeIncrease;
    bool saveToFile;
    int saveInterval;
    bool doStats;
    bool buildTestData;
    unsigned long randomseed;

    enum BenchType { BENCH_AS = 1, BENCH_TABLE,
#ifdef HAVE_GUILE
        BENCH_SCM,
#endif 
#ifdef HAVE_CYTHON
        BENCH_PYTHON,
#endif 
    };
    BenchType testKind;

    UUID UUID_begin;
    UUID UUID_end;
    typedef timepair_t (AtomSpaceBenchmark::*BMFn)();
    std::vector< BMFn > methodsToTest;

    float percentLinks;
    long atomCount; //! number of nodes to build atomspace with before testing

    bool showTypeSizes;
    void printTypeSizes();
    size_t estimateOfAtomSize(Handle h);

    AtomSpaceBenchmark();
    ~AtomSpaceBenchmark();

    void setMethod(std::string method);
    void showMethods();
    void startBenchmark(int numThreads=1);
    void doBenchmark(const std::string& methodName, BMFn methodToCall);

    void buildAtomSpace(long atomspaceSize=(1 << 16), float percentLinks = 0.1, 
                        bool display = true);
    Handle getRandomHandle();
    void setTestAllMethods() { setMethod("all"); }

    timepair_t bm_noop();

    timepair_t bm_getType();
    // Get and set TV and AV
    float chanceUseDefaultTV; // if set, this will use default TV for new atoms and bm_setTruthValue
    timepair_t bm_getTruthValue();
    timepair_t bm_setTruthValue();

#ifdef ZMQ_EXPERIMENT
    timepair_t bm_getTruthValueZmq();
#endif

    timepair_t bm_pointerCast();
    timepair_t bm_getIncomingSet();
    timepair_t bm_getIncomingSetSize();
    timepair_t bm_getOutgoingSet();
    timepair_t bm_getHandlesByType();

    timepair_t bm_addNode();
    timepair_t bm_addLink();
    timepair_t bm_rmAtom();

    timepair_t bm_push_back();
    timepair_t bm_push_back_reserve();
    timepair_t bm_emplace_back();
    timepair_t bm_emplace_back_reserve();
    timepair_t bm_reserve();
};

} // namespace opencog

#endif //_OPENCOG_AS_BENCHMARK_H
