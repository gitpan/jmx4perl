package org.jmx4perl.backend;

import org.jmx4perl.JmxRequest;

import javax.management.AttributeNotFoundException;
import javax.management.InstanceNotFoundException;
import javax.management.MBeanException;
import javax.management.ReflectionException;
import java.io.IOException;

/*
 * jmx4perl - WAR Agent for exporting JMX via JSON
 *
 * Copyright (C) 2009 Roland Huß, roland@cpan.org
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License
 * as published by the Free Software Foundation; either version 2
 * of the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.
 *
 * A commercial license is available as well. Please contact roland@cpan.org for
 * further details.
 */

/**
 * Interface for dispatching a request to a certain backend.
 *
 * @author roland
 * @since Nov 11, 2009
 */
public interface RequestDispatcher {
    /**
     * Dispatch a {@link org.jmx4perl.JmxRequest} to a certain backend
     * and return the result of the JMX action.
     *
     * @param pJmxReq the request to dispatch
     * @return result object
     * @throws InstanceNotFoundException when a certain MBean could not be found
     * @throws AttributeNotFoundException in case an attributes couldnt be resolved
     * @throws ReflectionException
     * @throws MBeanException
     */
    public Object dispatchRequest(JmxRequest pJmxReq)
            throws InstanceNotFoundException, AttributeNotFoundException, ReflectionException, MBeanException, IOException;

    /**
     * Check wether current dispatcher can handle the given request
     *
     * @param pJmxRequest request to check
     * @return true if this dispatcher can handle the request
     */
    boolean canHandle(JmxRequest pJmxRequest);
}
