# cython: infer_types=True
"""
Python bindings for the libsemigroups C++ library.

`libsemigroups <https://github.com/james-d-mitchell/libsemigroups/>`_
is a C++ mathematical library for computing with finite `semigroups
<https://en.wikipedia.org/wiki/Semigroup>`_. This Cython module
provides bindings to call it from Python.

We construct the semigroup generated by `0` and `-1`::

    >>> from semigroups import Semigroup
    >>> S = Semigroup([0, -1])
    >>> S.size()
    3

We construct the semigroup generated by `0` and complex number `i`::

    >>> S = Semigroup([0, 1j])
    >>> S.size()
    5
"""
cimport libsemigroups

from libc.stdint cimport uint16_t
from libcpp.vector cimport vector
from libcpp cimport bool
from libcpp.string cimport string
from libcpp.pair cimport pair
from libc.stdint cimport uint32_t

from cysignals.signals cimport sig_on, sig_off

cdef class ElementABC:
    """
    This abstract class provides common methods for its subclasses.

    Any subclass shall implement an ''__init__'' method which
    initializes _handle.
    """
    cdef libsemigroups.Element* _handle

    def __cinit__(self):
        self._handle = NULL
    
    cdef new_from_handle(self, libsemigroups.Element* handle):
        cdef ElementABC result = self.__class__(self)
        result._handle = handle[0].really_copy()
        return result
    
    def __dealloc__(self):
        if self._handle != NULL:
            self._handle[0].really_delete()
            del self._handle

    def __mul__(ElementABC self, ElementABC other):
        if not isinstance(self, type(other)):
            raise TypeError('Elements must be same type')
        elif self.degree() != other.degree():
            raise ValueError('Element degrees must be equal')
        cdef libsemigroups.Element* product = self._handle.identity()
        product.redefine(self._handle, other._handle)
        return self.new_from_handle(product)
  
    def __richcmp__(ElementABC self, ElementABC other, int op):
        if not isinstance(self, type(other)):
            raise TypeError('the arguments (elements) must be same type')
        elif op == 0:
            return self._handle[0] < other._handle[0]
        elif op == 1:
            return (self._handle[0] < other._handle[0] 
                    or self._handle[0] == other._handle[0])
        elif op == 2:
            return self._handle[0] == other._handle[0]
        elif op == 3:
            return not self._handle[0] == other._handle[0]
        elif op == 4:
            return not (self._handle[0] < other._handle[0] 
                        or self._handle[0] == other._handle[0])
        elif op == 5:
            return not self._handle[0] < other._handle[0]
    
    # TODO avoid creating new elements for every product here
    def __pow__(self, n, modulo):
        message = 'the argument (power) must be a non-negative integer'
        if not isinstance(n, int):
            raise TypeError(message)
        elif n < 0:
            raise ValueError(message)

        if n == 0:
            return self.identity()
        g = self
        if n % 2 == 1:
            x = self  # x = x * g
        else:
            x = self.identity()
        while n > 1:
            g *= g
            n //= 2
            if n % 2 == 1:
                x *= g
        return x

    def degree(self):
        '''
        Function for finding the degree of an element.

        This method returns an integer which represents the size of an element,
        and is used to determine whether or not two elements are compatible for
        multiplication.

        Returns:
            int: The degree of the element.

        Raises:
            TypeError:  If any argument is given.

        Example:
            >>> from semigroups import PartialPerm
            >>> PartialPerm([1, 2, 5], [2, 3, 5], 6).degree()
            6
        '''
        return self._handle.degree()

    def identity(self):
        '''
        Function for finding the mutliplicative identity FIXME.

        This function finds the multiplicative identity of the same element
        type and degree as the current element.

        Returns:
            Element: The identity element of the Element subclass.

        Raises:
            TypeError:  If any argument is given.

        Example:
            >>> from semigroups import PartialPerm
            >>> PartialPerm([0, 2], [1, 2], 3).identity()
            PartialPerm([0, 1, 2], [0, 1, 2], 3)
        '''
        cdef libsemigroups.Element* identity = self._handle.identity()
        out = self.new_from_handle(identity)
        identity[0].really_delete()
        return out


cdef class TransformationNC(ElementABC):
    def __init__(self, images):
        self._handle = new libsemigroups.Transformation[uint16_t](images)

    def __iter__(self):
        cdef libsemigroups.Element* e = self._handle
        e2 = <libsemigroups.Transformation[uint16_t] *>e
        for x in e2[0]:
            yield x

cdef class PartialPermNC(ElementABC):
    def __init__(self, images):
        self._handle = new libsemigroups.PartialPerm[uint16_t](images)

    def __iter__(self):
        cdef libsemigroups.Element* e = self._handle
        e2 = <libsemigroups.PartialPerm[uint16_t] *>e
        for x in e2[0]:
            yield x

    def rank(self):
        '''
        Method for finding the rank of the partial permutation.

        Returns:
            int: The rank of the partial permutation.

        Raises:
            TypeError:  If any argument is given.

        Example:
            >>> from semigroups import PartialPerm
            >>> PartialPerm([1, 2, 5], [2, 3, 5], 6).rank()
            3
        '''
        cdef libsemigroups.Element* e = self._handle
        e2 = <libsemigroups.PartialPerm[uint16_t] *>e
        return e2.crank()

cdef class BipartitionNC(ElementABC):
    def __init__(self, blocks_lookup):
        self._handle = new libsemigroups.Bipartition(blocks_lookup)

    def __iter__(self):
        cdef libsemigroups.Element* e = self._handle
        e2 = <libsemigroups.Bipartition *>e
        for x in e2[0]:
            yield x

    def nr_blocks(self):
        '''Method for finding the number of blocks of a bipartition.

        Returns:
            int: The number blocks of the bipartition.

        Raises:
            TypeError:  If any argument is given.

        Example:
            >>> from semigroups import Bipartition
            >>> Bipartition([1, 2], [-2, -1, 3], [-3]).nr_blocks()
            3
        '''
        cdef libsemigroups.Element* e = self._handle
        e2 = <libsemigroups.Bipartition *>e
        return e2.const_nr_blocks()

    def block(self, index):
        cdef libsemigroups.Element* e = self._handle
        e2 = <libsemigroups.Bipartition *>e
        return e2.block(index)

    def is_transverse_block(self, index):
        '''
        Function for finding whether a given block is transverse.

        A block is transverse if it contains both positive and negative
        elements.

        Args:
            index (int): The index of the block in question.

        Returns:
            list: The blocks of the bipartition.

        Raises:
            TypeError:  If index is not an int.
            IndexError: If index does not relate to the index of a block in the
                        partition.

        Example:
            >>> from semigroups import Bipartition
            >>> Bipartition([1, 2], [-2, -1, 3], [-3]).is_transverse_block(1)
            True
        '''
        if not isinstance(index, int):
            raise TypeError('Index must be an integer')
        elif index < 0 or index >= self.nr_blocks():
            raise IndexError('the argument (index) must be in the range 0 '
                             + 'to %d' % (self.nr_blocks() - 1))
        cdef libsemigroups.Element* e = self._handle
        e2 = <libsemigroups.Bipartition *>e
        return e2.is_transverse_block(index)

cdef class BooleanMatNC(ElementABC):
    def __init__(self, rows):
        self._handle = new libsemigroups.BooleanMat(rows)

    def __iter__(self): # iterate through values in the matrix
        cdef libsemigroups.Element* e = self._handle
        e2 = <libsemigroups.BooleanMat *>e
        for x in e2[0]:
            yield x

cdef class PBRNC(ElementABC):
    def __init__(self, adj):
        self._handle = new libsemigroups.PBR(adj)

    def __iter__(self):
        cdef libsemigroups.Element* e = self._handle
        e2 = <libsemigroups.PBR *>e
        for x in e2[0]:
            yield x

cdef class PythonElementNC(ElementABC):
    """
    A class for handles to libsemigroups elements that themselves wrap
    back a Python element

    EXAMPLE::

        >>> from semigroups import Semigroup, PythonElement
        >>> x = PythonElement(-1); x
        -1

        >>> Semigroup([PythonElement(-1)]).size()
        2
        >>> Semigroup([PythonElement(1)]).size()
        1
        >>> Semigroup([PythonElement(0)]).size()
        1
        >>> Semigroup([PythonElement(0), PythonElement(-1)]).size()
        3

        x = [PythonElement(-1)]
        x = 2

        sage: W = SymmetricGroup(4)
        sage: pi = W.simple_projections()
        sage: F = FiniteSetMaps(W)
        sage: S = Semigroup([PythonElement(F(p)) for p in pi])
        sage: S.size()
        23

    TESTS::

        Testing reference counting::

            >>> s = "UN NOUVEL OBJET"
            >>> sys.getrefcount(s)
            2
            >>> x = PythonElement(s)
            >>> sys.getrefcount(s)
            3
            >>> del x
            >>> sys.getrefcount(s)
            2
    """
    def __init__(self, value):
        if value is not None:
            self._handle = new libsemigroups.PythonElement(value)

    def get_value(self):
        """

        """
        return (<libsemigroups.PythonElement *>self._handle).get_value()

    def __repr__(self):
        return repr(self.get_value())


# TODO Currently there seems to be no point in putting this into semigrp.py
# since almost every method has no checks but just calls the corresponding
# method for the C++ object. 

cdef class SemigroupNC:
    # holds a pointer to the C++ instance which we're wrapping
    cdef libsemigroups.Semigroup* _handle      
    cdef ElementABC _an_element

    def __cinit__(self):
        self._handle = NULL

    def __init__(self, gens):
        cdef vector[libsemigroups.Element *] cpp_gens
        for g in gens:
            cpp_gens.push_back((<ElementABC>g)._handle)
        self._handle = new libsemigroups.Semigroup(cpp_gens)
        self._an_element = gens[0]

    def __dealloc__(self):
        del self._handle

    def current_max_word_length(self):
        """
        Let :math:`X` be a set (*alphabet*). A *short-lex order* on :math:`X`
        is a total order of the set of all finite sequences (*words*) of
        elements of :math:`X`.

        Let :math:`S` be a semigroup generated by a set :math:`X`. Every
        element of :math:`S` can be represented as a product of elements of
        :math:`X`. Therefore if :math:`X` is viewed as an alphabet, all
        elements of :math:`S` can be viewed as words.

        When a semigroup is generated using the Semigroup class, a short-lex
        order is induced on the semigroup, where the generators are ordered in
        the order that they are passed to the function. The short-lex order
        follows by comparing the first unequal letters in two words, to compare
        the words.

        This method returns the length of the longest word in the generators
        that has so far been enumerated.

        Returns:
            int: Length of the longest word that has been enumerated.

        Raises:
            TypeError:  If any arguments are passed.

        Examples:
            >>> from semigroups import Semigroup, Transformation
            >>> S = Semigroup(Transformation([1, 0]), Transformation([0, 0]))
            >>> S.current_max_word_length()
            1
            >>> S.size()
            4
            >>> S.current_max_word_length()
            2
        """
        return self._handle.current_max_word_length()

    def size(self):
        """
        A function to find the number of elements in a semigroup.

        Returns:
            int: The number of elements of the semigroup.

        Raises:
            TypeError:  If any arguments are passed.

        Examples:

            >>> from semigroups import Semigroup, Transformation
            >>> S = Semigroup([Transformation([1, 1, 4, 5, 4, 5]),
            ...                Transformation([2, 3, 2, 3, 5, 5])])
            >>> S.size()
            5
        """
        # Plausibly wrap in sig_off / sig_on
        return self._handle.size()

    def nridempotents(self):
        r'''
        An element :math:`a` of a semigroup is an *idempotent* if :math:`a^2
        =a`.

        This is a function for finding the number of idempotents of a 
        semigroup.

        Returns:
            int: The number of idempotents of the semigroup.

        Raises:
            TypeError:  If any arguments are passed.

        Examples:
            >>> from semigroups import Semigroup, Transformation
            >>> S = Semigroup(Transformation([1, 0]), Transformation([0, 0]))
            >>> S.nridempotents()
            3                    
            >>> Transformation([0, 1]) ** 2
            Transformation([0, 1])
            >>> Transformation([1, 0]) ** 2
            Transformation([0, 1])
            >>> Transformation([1, 1]) ** 2
            Transformation([1, 1])
            >>> Transformation([0, 0]) ** 2
            Transformation([0, 0])
        '''
        return self._handle.nridempotents()
    
    def is_done(self):
        """
        A semigroup is fully enumerated when the product of every element by
        every generator is known.
        
        This is a function for finding if a semigroup is fully enumerated.

        Returns:
            bool: Whether or not the semigroup is fully enumerated.

        Raises:
            TypeError:  If any arguments are passed.

        Examples:
            >>> from semigroups import Semigroup, Bipartition
            >>> S = Semigroup(Bipartition([1, -1], [2, 3, -3], [-2]))
            >>> S.is_done()
            False
            >>> S.size()
            1
            >>> S.is_done()
            True
        """

        return self._handle.is_done()
    
    def is_begun(self):
        """
        Function for finding if any non-generator elements of a semigroup are
        known.

        Returns:
            bool: Whether or not any elements have been enumerated.

        Raises:
            TypeError:  If any arguments are passed.

        Examples:
            >>> from semigroups import Semigroup, Bipartition
            >>> S = Semigroup(Bipartition([1, -1], [2, 3, -3], [-2]))
            >>> S.is_begun()
            False
            >>> S.size()
            1
            >>> S.is_begun()
            True
        """
        return self._handle.is_begun()
    
    def current_position(self, ElementABC x):
        """
        A function for finding the position that an enumerated element is
        stored. 

        If the element has not been enumerated, or is not in the semigroup, the
        function returns None.

        
        Args:
            x (semigroups.libsemigroups.ElementABC): The element.

        Returns:
            int or None: The position of the element.

        Examples:
            >>> from semigroups import Semigroup, Transformation
            >>> S = Semigroup(Transformation([1, 2, 0]),
            ... Transformation([2, 1, 0]))
            >>> S.current_position(Transformation([0, 1, 2]))
            >>> Transformation([0, 1, 2]) in S
            True
            >>> S.current_position(Transformation([0, 1, 2]))
            5
        """

        pos = self._handle.current_position(x._handle)
        if pos == -1:
            return None # TODO Ok?
        return pos
    
    def __contains__(self, ElementABC x):
        return self._handle.test_membership(x._handle)

    def set_report(self, val):
        #FIXME val not appearing as arg in documentation
        """
        Function to instruct other functions to print information about the
        progress of the computation.

        Args:
            val (bool):  Whether to set the reporting to True or False.

        Returns:
            None

        Examples:
            >>> from semigroups import Semigroup, Transformation
            >>> S = Semigroup(Transformation([0, 1, 2]), Transformation([0, 0, 0]))
            >>> S.set_report(True)
            >>> S.size()
            Thread #0: Semigroup::enumerate: limit = 18446744073709551615
            Thread #0: Semigroup::enumerate: elapsed time = 3127ns 
            2
        """
        if val == True:
            self._handle.set_report(1)
        else:
            self._handle.set_report(0)

    def factorisation(self, ElementABC x):
        r'''
        Function to express an element of a semigroup as a product of the
        generators. It returns a list of ints, where the integer :math:`i`
        represents the :math:`i\text{th}` generator passed.

        Args:
            x (semigroups.libsemigroups.ElementABC): The element.

        Returns:
            list: A list of the indices of generators in the factorisation.

        Examples:
            >>> from semigroups import Semigroup, Transformation
            >>> S = Semigroup(Transformation([1, 0, 2]),
            ... Transformation([0, 0, 2]), Transformation([2, 0, 1]))
            >>> S.factorisation(Transformation([0, 0, 0]))
            [1, 0, 2, 1]
            >>> S[1] * S[0] * S[2] * S[1]
            Transformation([0, 0, 0])

            >>> from semigroups import FullTransformationMonoid
            >>> S = FullTransformationMonoid(5)
            >>> S.factorisation(Transformation([0, 0, 0, 0, 0]))
            [1, 0, 2, 1, 0, 2, 1, 0, 2, 1]
            >>> S[1] * S[0] * S[2] * S[1] * S[0] * S[2] * S[1] * S[0] * S[2] * S[1]
            Transformation([0, 0, 0, 0, 0])
        '''
        pos = self._handle.position(x._handle)
        if pos == -1:
            return None # TODO Ok?
        cdef vector[size_t]* c_word = self._handle.factorisation(pos)
        assert c_word != NULL
        py_word = [letter for letter in c_word[0]]
        del c_word
        return py_word
    
    def enumerate(self, limit):
        self._handle.enumerate(limit)

    cdef new_from_handle(self, libsemigroups.Element* handle):
        return self._an_element.new_from_handle(handle)

    def __getitem__(self, size_t pos):
        """
        Return the ``pos``-th element of ``self``.

        EXAMPLES::

            >>> from semigroups import Semigroup
            >>> S = Semigroup([1j])
            >>> S[0]
            1j
            >>> S[1]
            (-1+0j)
            >>> S[2]
            (-0-1j)
            >>> S[3]
            (1-0j)
        """
        cdef libsemigroups.Element* element
        element = self._handle.at(pos)
        if element == NULL:
            return None
        else:
            return self.new_from_handle(element)

    def __iter__(self):
        """
        An iterator over the elements of self.

        EXAMPLES::

            >>> from semigroups import Semigroup
            >>> S = Semigroup([1j])
            >>> for x in S:
            ...     print(x)
            1j
            (-1+0j)
            (-0-1j)
            (1-0j)
        """
        cdef size_t pos = 0
        cdef libsemigroups.Element* element
        while True:
            element = self._handle.at(pos)
            if element == NULL:
                break
            else:
                yield self.new_from_handle(element)
            pos += 1


# FIXME should be a subclass of SemigroupNC
cdef class FpSemigroupNC:
    cdef libsemigroups.Congruence* _congruence
    cdef libsemigroups.RWS* _rws
    
    def __convert_word(self, word):
        return [self.alphabet.index(i) for i in word]

    def __convert_rel(self, rel):
        return [self.__convert_word(w) for w in rel]

    def __init__(self, nrgens, rels):
        rels = [self.__convert_rel(rel) for rel in rels]
        self._congruence = new libsemigroups.Congruence("twosided",
                                                        nrgens,
                                                        [],
                                                        rels)
        self._rws = new libsemigroups.RWS(rels)
    
    def __dealloc__(self):
        del self._congruence
        del self._rws

    def size(self):
        sig_on()
        try:
            return self._congruence.nr_classes()
        finally:
            sig_off()
        # FIXME must actually kill off the nr_classes process safely

    def set_report(self, val):
        '''
        toggles whether or not to report data when running certain functions

        Args:
            bool:toggle to True or False
        '''
        if val != True and val != False:
            raise TypeError('the argument must be True or False')
        if val:
            self._congruence.set_report(1)
        else:
            self._congruence.set_report(0)

    def set_max_threads(self, nr_threads):
        '''
        sets the maximum number of threads to be used at once.

        Args:
            int:number of threads
        '''
        return self._congruence.set_max_threads(nr_threads)

    def is_confluent(self):
        '''
        check if the relations of the FpSemigroup are confluent.

        Examples:
            >>> FpSemigroup(["a","b"],[["aa","a"],["bbb","ab"],
                                                  ["ab","ba"]).is_confluent()
            True
            >>> FpSemigroup(["a","b"],[["aa","a"],["bab","ab"],
                                                  ["ab","ba"]).is_confluent()
            False

        Returns:
            bool: True for confluent, False otherwise.
        '''
        return self._rws.is_confluent()

    def word_to_class_index(self, word):
        return self._congruence.word_to_class_index(self.__convert_word(word))
