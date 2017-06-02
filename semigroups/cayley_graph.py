'''
This module contains classes for representing semigroups.
'''
# pylint: disable = no-member, protected-access, invalid-name, len-as-condition
# pylint: disable = cell-var-from-loop

import networkx

class CayleyGraph:
    r"""
    A *directed graph* is a pair :math:`G = (V, E)`, where :math:`V` is a set,
    called the *nodes* of :math:`G`, and :math:`E` is a set of ordered pairs of
    elements of :math:`V`, called the *edges* of :math:`G`.

    Let :math:`S` be a semigroup, generated by a set :math:`X`. Let
    :math:`G` be a directed graph with node set :math:`S`, and for any
    :math:`x, y \in S`, there is an edge from :math:`x` to :math:`y` if
    :math:`y = xz` for some :math:`z \in X`. This graph is called a *right
    Cayley graph* of :math:`S`. The *left Cayley graph* is defined similarly,
    except with the multiplication on the left.

    This is a class for representing right and left Cayley graphs of semigroups.
    """

    def __init__(self):
        self._label_edge_list = []
        self._graph = networkx.classes.multidigraph.MultiDiGraph()

    def __eq__(self, other):
        return self.ordered_adjacencies() == other.ordered_adjacencies()

    def __ne__(self, other):
        return not self == other

    def _add_node(self, node):
        self._graph.add_node(node)

    def _add_edge_with_label(self, label, edge):
        self._graph.add_edge(*edge)
        self._label_edge_list.append((label, edge))

    def ordered_adjacencies(self):
        r"""
        Let :math:`G` be a directed graph, and :math:`v` be node of :math:`G`.
        A node :math:`u` is *adjacent* to :math:`v` if :math:`vu` is an edge.

        This function finds all of the nodes that every node is adjacent to,
        represented as a list, where the :math:`i\text{th}` entry in the list
        contains a list of nodes that are adjacent to :math:`i`.

        Raises:
            TypeError: If any arguments are given.

        Returns:
            list: The edges of the Cayley graph.

        Examples:
            >>> from semigroups import Semigroup, Transformation
            >>> S = Semigroup(Transformation([0, 0]),
            ... Transformation([1, 0]))
            >>> G = S.right_cayley_graph()
            >>> G.ordered_adjacencies()
            [[0, 2], [0, 3], [0, 0], [0, 1]]
        """
        return self._adjacencies_list

    def edges(self):
        """
        Function for finding the edges of the Cayley graph. Each edge is
        represented by a tuple, with first entry representing the start node,
        and second entry representing the end node.

        Raises:
            TypeError: If any arguments are given.

        Returns:
            list: The edges of the Cayley graph.

        Examples:
            >>> from semigroups import Semigroup, Transformation
            >>> S = Semigroup(Transformation([0, 0]),
            ... Transformation([1, 0]))
            >>> G = S.right_cayley_graph()
            >>> G.edges()
            [(0, 0), (0, 2), (1, 0), (1, 3), (2, 0), (2, 0), (3, 0), (3, 1)]
        """
        return list(map(lambda x: x[1], self._label_edge_list))

    def nodes(self):
        """
        Function for finding the nodes of the Cayley graph.

        Raises:
            TypeError: If any arguments are given.

        Returns:
            list: The nodes of the Cayley graph.

        Examples:
            >>> from semigroups import Semigroup, Transformation
            >>> S = Semigroup(Transformation([0, 0]),
            ... Transformation([1, 0]))
            >>> G = S.right_cayley_graph()
            >>> G.nodes()
            [0, 1, 2, 3]
        """
        return self._graph.nodes()

    def strongly_connected_components(self):
        r"""
        Let :math:`G` be a directed graph. A *path* on :math:`G` is a sequence
        :math:`(v_n)_n` of nodes of :math:`G`, such that :math:`v_nv_{n+1}`
        is an edge :math:`\forall n`.

        A *strongly connected component* is a subgraph :math:`H` of :math:`G`,
        such that for any two nodes :math:`u,v \in H`, there is a path from
        :math:`u` to :math:`v`.

        This function finds a list of all strongly connected components, each
        represented as a set of nodes.

        Raises:
            TypeError: If any arguments are given.

        Returns:
            list: The strongly connected components.

        Examples:
            >>> from semigroups import Semigroup, Transformation
            >>> S = Semigroup(Transformation([0, 0]),
            ... Transformation([1, 0]))
            >>> G = S.right_cayley_graph()
            >>> G.strongly_connected_components()
            [{0, 2}, {1, 3}]
        """
        return list(networkx.strongly_connected_components(self._graph))
