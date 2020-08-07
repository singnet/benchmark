/*
 * evaluationlink_bm.cc
 *
 * Copyright (C) 2018 OpenCog Foundation
 * All Rights Reserved
 *
 * Created by Vitaly Bogdanov <vsbogd@gmail.com> May 29, 2018
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU Affero General Public License v3 as
 * published by the Free Software Foundation and including the exceptions
 * at http://opencog.org/wiki/Licenses
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU Affero General Public License
 * along with this program; if not, write to:
 * Free Software Foundation, Inc.,
 * 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
 */

#include <benchmark/benchmark.h>

#include <opencog/util/Logger.h>
#include <opencog/atoms/base/Atom.h>
#include <opencog/atoms/base/Node.h>
#include <opencog/atoms/base/Link.h>
#include <opencog/atomspace/AtomSpace.h>

#include "benchmark.h"

using namespace opencog;

static Handle create_evaluation_link(size_t i)
{
	// The numbers 101 and 233 are prime numbers, so this whole
	// thing will interconnect to form some nice polytope.
	return createLink(EVALUATION_LINK,
		createNode(PREDICATE_NODE, "kind-of " + std::to_string(i%11)),
		createLink(LIST_LINK,
			createNode(CONCEPT_NODE, "barfology" + std::to_string(i%101)),
			createNode(CONCEPT_NODE, "blingometry" + std::to_string(i%233))));
}

static void BM_CreateEvaluationLink(benchmark::State& state)
{
	size_t j = 0;
	for (auto _ : state)
	{
		if (j % 5 == 0) // we are creating 5 atoms per pop.
			create_evaluation_link(0);
		j++;
	}
}
BENCHMARK(BM_CreateEvaluationLink);

static void BM_AddSameEvaluationLink(benchmark::State& state)
{
	AtomSpace* as = new AtomSpace;

	size_t j = 0;
	logger().fine("atomspace size before adding: %d", as->get_size());
	for (auto _ : state)
	{
		if (j % 5 == 0) // we are creating 5 atoms per pop.
		{
			// Create multiple copies of the same atom.
			// The AtomSpace takes over memory management of the
			// added C++ Atom, so we have to keep feeding it unique Atoms.
			as->add_atom(create_evaluation_link(0));
		}
		j++;
	}

	logger().fine("atomspace size after adding: %d", as->get_size());
	delete as;
}
BENCHMARK(BM_AddSameEvaluationLink);

static void BM_AddEvalLink(benchmark::State& state)
{
	AtomSpace* as = new AtomSpace;

	const size_t number_of_links = state.range(0);
	std::vector<Handle> links(number_of_links);

	for (size_t i = 0; i < number_of_links; ++i)
		links[i] = create_evaluation_link(i);

	logger().fine("atomspace size before adding: %d", as->get_size());

	size_t i = 0;
	size_t j = 0;
	for (auto _ : state)
	{
		if (j < as->get_size()) // we are creating 5 atoms per pop.
			as->add_atom(links[i++ % number_of_links]);
		j++;
		if (number_of_links < j)
		{
			as->clear();
			j = 0;
		}
	}

	logger().fine("atomspace size after adding: %d", as->get_size());
	delete as;
}

// Cannot go higher than 17 because the benchmark doesn't
// iterate enough times.
BENCHMARK(BM_AddEvalLink)->Arg(2<<9)->Arg(2<<16)->Arg(2<<17);

static void BM_CreateAddEvalLink(benchmark::State& state)
{
	const size_t num_to_add = state.range(0);
	AtomSpace* as = new AtomSpace;

	logger().fine("atomspace size before adding: %d", as->get_size());

	size_t i = 0;
	size_t j = 0;
	for (auto _ : state)
	{
		if (j < as->get_size()) // we are creating 5 atoms per pop.
			as->add_atom(create_evaluation_link(i++));
		j++;
		if (num_to_add < j)
		{
			as->clear();
			j = 0;
		}
	}

	logger().fine("atomspace size after adding: %d", as->get_size());
	delete as;
}

// Cannot go higher than 17 because the benchmark doesn't
// iterate enough times.
BENCHMARK(BM_CreateAddEvalLink)->Arg(2<<9)->Arg(2<<16)->Arg(2<<17);
